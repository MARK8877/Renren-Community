package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"creatorhub/api/internal/account"
	"creatorhub/api/internal/auth"
	"creatorhub/api/internal/chat"
	"creatorhub/api/internal/config"
	"creatorhub/api/internal/database"
	"creatorhub/api/internal/friend"
	"creatorhub/api/internal/scraper"
	"creatorhub/api/internal/video"
	"golang.org/x/crypto/bcrypt"
)

type response struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}
type userData struct {
	ID        uint64 `json:"id"`
	Email     string `json:"email,omitempty"`
	Phone     string `json:"phone,omitempty"`
	Nickname  string `json:"nickname"`
	AvatarURL string `json:"avatarUrl,omitempty"`
	Role      string `json:"role"`
}
type authData struct {
	AccessToken string    `json:"accessToken"`
	ExpiresAt   time.Time `json:"expiresAt"`
	User        userData  `json:"user"`
}

type scraperController interface {
	Trigger(context.Context, scraper.TriggerType) (scraper.Job, error)
	Status(context.Context) (scraper.StatusSnapshot, error)
}

type schedulerView interface {
	NextRunAt() time.Time
}

type server struct {
	accounts         *account.Repository
	chats            *chat.Repository
	friends          *friend.Repository
	videos           *video.Repository
	tokens           *auth.TokenManager
	scraper          scraperController
	scraperScheduler schedulerView
}

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("load config: %v", err)
	}
	db, err := database.OpenMySQL(context.Background(), cfg.Database)
	if err != nil {
		log.Fatalf("connect mysql: %v", err)
	}
	defer db.Close()
	scraperStore := scraper.NewRepository(db)
	scraperCommand := scraper.NewPythonCommand(".", cfg.Scraper.PythonBin, cfg.Scraper.ScriptPath, scraper.DefaultLimit)
	scraperService := scraper.NewService(scraperStore, scraperCommand, cfg.Scraper.Timeout)
	if err := scraperService.MarkStale(context.Background()); err != nil {
		log.Printf("mark stale video scrape jobs: %v", err)
	}
	scheduler := scraper.NewScheduler(scraperService, cfg.Scraper.Interval)
	api := &server{
		accounts:         account.NewRepository(db),
		chats:            chat.NewRepository(db),
		friends:          friend.NewRepository(db),
		videos:           video.NewRepository(db),
		tokens:           auth.NewTokenManager(cfg.Auth.TokenSecret, cfg.Auth.TokenTTL),
		scraper:          scraperService,
		scraperScheduler: scheduler,
	}
	mux := http.NewServeMux()
	registerDocsRoutes(mux)
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) { writeJSON(w, 200, response{Code: 0, Message: "ok"}) })
	mux.HandleFunc("GET /api/v1/videos", api.requireAuth(api.listVideos))
	mux.HandleFunc("POST /api/v1/admin/scraper/run", api.requireAdmin(api.runScraper))
	mux.HandleFunc("GET /api/v1/admin/scraper/status", api.requireAdmin(api.scraperStatus))
	mux.HandleFunc("POST /api/v1/auth/register", api.register)
	mux.HandleFunc("POST /api/v1/auth/login", api.login(false))
	mux.HandleFunc("POST /api/v1/admin/login", api.login(true))
	mux.HandleFunc("GET /api/v1/auth/me", api.requireAuth(api.me))
	mux.HandleFunc("GET /api/v1/conversations", api.requireAuth(api.listConversations))
	mux.HandleFunc("POST /api/v1/conversations/read-all", api.requireAuth(api.markAllConversationsRead))
	mux.HandleFunc("POST /api/v1/conversations/groups", api.requireAuth(api.createGroup))
	mux.HandleFunc("GET /api/v1/conversations/{key}/group", api.requireAuth(api.groupDetails))
	mux.HandleFunc("PATCH /api/v1/conversations/{key}/group", api.requireAuth(api.updateGroup))
	mux.HandleFunc("GET /api/v1/conversations/{key}/members", api.requireAuth(api.groupMembers))
	mux.HandleFunc("POST /api/v1/conversations/{key}/members/invite", api.requireAuth(api.inviteGroupMember))
	mux.HandleFunc("PATCH /api/v1/conversations/{key}/members/{userID}/role", api.requireAuth(api.setGroupMemberRole))
	mux.HandleFunc("PATCH /api/v1/conversations/{key}/members/{userID}/mute", api.requireAuth(api.setGroupMemberMute))
	mux.HandleFunc("DELETE /api/v1/conversations/{key}/members/{userID}", api.requireAuth(api.removeGroupMember))
	mux.HandleFunc("DELETE /api/v1/conversations/{key}/leave", api.requireAuth(api.leaveGroup))
	mux.HandleFunc("PATCH /api/v1/conversations/{key}/owner", api.requireAuth(api.transferGroupOwner))
	mux.HandleFunc("GET /api/v1/conversations/{key}/join-requests", api.requireAuth(api.listJoinRequests))
	mux.HandleFunc("POST /api/v1/conversations/{key}/join-requests/{id}/resolve", api.requireAuth(api.resolveJoinRequest))
	mux.HandleFunc("GET /api/v1/conversations/{key}/messages", api.requireAuth(api.listMessages))
	mux.HandleFunc("POST /api/v1/conversations/{key}/messages", api.requireAuth(api.createMessage))
	mux.HandleFunc("POST /api/v1/conversations/{key}/read", api.requireAuth(api.markConversationRead))
	mux.HandleFunc("GET /api/v1/users/search", api.requireAuth(api.searchUsers))
	mux.HandleFunc("GET /api/v1/friends", api.requireAuth(api.listFriends))
	mux.HandleFunc("GET /api/v1/friend-requests", api.requireAuth(api.listFriendRequests))
	mux.HandleFunc("POST /api/v1/friend-requests", api.requireAuth(api.sendFriendRequest))
	mux.HandleFunc("POST /api/v1/friend-requests/{id}/accept", api.requireAuth(api.acceptFriendRequest))
	mux.HandleFunc("POST /api/v1/friend-requests/{id}/reject", api.requireAuth(api.rejectFriendRequest))
	httpServer := &http.Server{Addr: ":" + cfg.AppPort, Handler: cors(mux), ReadHeaderTimeout: 5 * time.Second}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go scheduler.Run(ctx)

	serverErrors := make(chan error, 1)
	go func() {
		log.Printf("CreatorHub API listening on %s", httpServer.Addr)
		serverErrors <- httpServer.ListenAndServe()
	}()
	select {
	case <-ctx.Done():
		shutdownContext, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := httpServer.Shutdown(shutdownContext); err != nil {
			log.Printf("shutdown API server: %v", err)
		}
	case err := <-serverErrors:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("serve API: %v", err)
		}
	}
}

func (s *server) register(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Identifier string `json:"identifier"`
		Password   string `json:"password"`
		Nickname   string `json:"nickname"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	input.Identifier = strings.TrimSpace(strings.ToLower(input.Identifier))
	input.Nickname = strings.TrimSpace(input.Nickname)
	if input.Identifier == "" || input.Nickname == "" || len(input.Password) < 8 {
		writeJSON(w, 400, response{Code: 10001, Message: "账号、昵称不能为空，密码至少 8 位"})
		return
	}
	if _, err := s.accounts.ByIdentifier(r.Context(), input.Identifier); err == nil {
		writeJSON(w, 409, response{Code: 10002, Message: "账号已注册"})
		return
	} else if !errors.Is(err, account.ErrNotFound) {
		writeJSON(w, 500, response{Code: 10500, Message: "查询账号失败"})
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Password), bcrypt.DefaultCost)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "创建账号失败"})
		return
	}
	email, phone := "", input.Identifier
	if strings.Contains(input.Identifier, "@") {
		email, phone = input.Identifier, ""
	}
	user, err := s.accounts.Create(r.Context(), email, phone, string(hash), input.Nickname)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "创建账号失败"})
		return
	}
	s.respondWithToken(w, user)
}

func (s *server) login(adminOnly bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var input struct {
			Identifier string `json:"identifier"`
			Password   string `json:"password"`
		}
		if !decodeJSON(w, r, &input) {
			return
		}
		user, err := s.accounts.ByIdentifier(r.Context(), strings.TrimSpace(strings.ToLower(input.Identifier)))
		if err != nil || bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(input.Password)) != nil {
			writeJSON(w, 401, response{Code: 10101, Message: "账号或密码错误"})
			return
		}
		if user.Status != "active" {
			writeJSON(w, 403, response{Code: 10103, Message: "账号已被停用"})
			return
		}
		if adminOnly && user.Role != "admin" {
			writeJSON(w, 403, response{Code: 10103, Message: "无管理员权限"})
			return
		}
		_ = s.accounts.RecordLogin(r.Context(), user.ID)
		s.respondWithToken(w, user)
	}
}

func (s *server) respondWithToken(w http.ResponseWriter, user account.User) {
	token, expiresAt, err := s.tokens.Create(user.ID, user.Role)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "生成登录凭证失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: authData{AccessToken: token, ExpiresAt: expiresAt, User: publicUser(user)}})
}
func (s *server) me(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	user, err := s.accounts.ByID(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, 404, response{Code: 10404, Message: "用户不存在"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: publicUser(user)})
}

func (s *server) listVideos(w http.ResponseWriter, r *http.Request, _ auth.Claims) {
	platform, page, pageSize := parseVideoQuery(r)
	items, err := s.videos.List(r.Context(), platform, page, pageSize)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取视频失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: items})
}

type scraperRunData struct {
	JobID uint64 `json:"jobId"`
}

type scraperStatusData struct {
	Running   bool         `json:"running"`
	Latest    *scraper.Job `json:"latest,omitempty"`
	NextRunAt *time.Time   `json:"nextRunAt,omitempty"`
}

func (s *server) runScraper(w http.ResponseWriter, r *http.Request, _ auth.Claims) {
	if s.scraper == nil {
		writeJSON(w, 500, response{Code: 10500, Message: "采集服务未初始化"})
		return
	}
	job, err := s.scraper.Trigger(r.Context(), scraper.TriggerManual)
	if errors.Is(err, scraper.ErrAlreadyRunning) {
		writeJSON(w, 409, response{Code: 10409, Message: "采集任务正在运行"})
		return
	}
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "启动采集任务失败"})
		return
	}
	writeJSON(w, 202, response{Code: 0, Message: "采集任务已启动", Data: scraperRunData{JobID: job.ID}})
}

func (s *server) scraperStatus(w http.ResponseWriter, r *http.Request, _ auth.Claims) {
	if s.scraper == nil {
		writeJSON(w, 500, response{Code: 10500, Message: "采集服务未初始化"})
		return
	}
	snapshot, err := s.scraper.Status(r.Context())
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取采集状态失败"})
		return
	}
	data := scraperStatusData{Running: snapshot.Running, Latest: snapshot.Latest}
	if s.scraperScheduler != nil {
		nextRunAt := s.scraperScheduler.NextRunAt()
		data.NextRunAt = &nextRunAt
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: data})
}

func parseVideoQuery(r *http.Request) (platform string, page, pageSize int) {
	query := r.URL.Query()
	platform = strings.ToLower(strings.TrimSpace(query.Get("platform")))
	page = 1
	if value, err := strconv.Atoi(query.Get("page")); err == nil && value > 0 {
		page = value
	}
	pageSize = 20
	if value, err := strconv.Atoi(query.Get("pageSize")); err == nil && value > 0 {
		pageSize = value
	}
	if pageSize > 100 {
		pageSize = 100
	}
	return platform, page, pageSize
}

func (s *server) listConversations(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	if err := s.chats.EnsureDefaults(r.Context(), claims.UserID); err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "初始化会话失败"})
		return
	}
	items, err := s.chats.ListConversations(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取会话失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: items})
}

func (s *server) createGroup(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	var input struct {
		Name                string `json:"name"`
		AvatarAssetKey      string `json:"avatarAssetKey"`
		Announcement        string `json:"announcement"`
		JoinMode            string `json:"joinMode"`
		MemberInviteEnabled *bool  `json:"memberInviteEnabled"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	input.Name = strings.TrimSpace(input.Name)
	if len([]rune(input.Name)) < 2 || len([]rune(input.Name)) > 30 {
		writeJSON(w, 400, response{Code: 10400, Message: "群名称需为 2 至 30 个字符"})
		return
	}
	if input.JoinMode == "" {
		input.JoinMode = "direct"
	}
	if input.JoinMode != "direct" && input.JoinMode != "approval" {
		writeJSON(w, 400, response{Code: 10400, Message: "入群方式不正确"})
		return
	}
	if len([]rune(input.Announcement)) > 500 {
		writeJSON(w, 400, response{Code: 10400, Message: "群公告最多 500 个字符"})
		return
	}
	key := fmt.Sprintf("group-%d-%d", claims.UserID, time.Now().UnixNano())
	inviteEnabled := true
	if input.MemberInviteEnabled != nil {
		inviteEnabled = *input.MemberInviteEnabled
	}
	group, err := s.chats.CreateGroupWithSettings(r.Context(), claims.UserID, key, input.Name, chat.GroupSettings{
		AvatarAssetKey:      strings.TrimSpace(input.AvatarAssetKey),
		Announcement:        strings.TrimSpace(input.Announcement),
		JoinMode:            input.JoinMode,
		MemberInviteEnabled: inviteEnabled,
	})
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "创建群聊失败"})
		return
	}
	writeJSON(w, 201, response{Code: 0, Message: "ok", Data: group})
}

func writeGroupError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, chat.ErrNotFound):
		writeJSON(w, 404, response{Code: 10404, Message: "群聊或成员不存在"})
	case errors.Is(err, chat.ErrForbidden):
		writeJSON(w, 403, response{Code: 10403, Message: "没有群管理权限"})
	case errors.Is(err, chat.ErrOwnerCannotLeave):
		writeJSON(w, 409, response{Code: 10409, Message: "群主不能直接退出，请先转让群主"})
	case errors.Is(err, chat.ErrInvalidOwnerTransfer):
		writeJSON(w, 409, response{Code: 10410, Message: "群主转让目标无效"})
	default:
		writeJSON(w, 500, response{Code: 10500, Message: "群管理操作失败"})
	}
}

func (s *server) leaveGroup(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	if err := s.chats.LeaveGroup(r.Context(), claims.UserID, r.PathValue("key")); err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "已退出群聊"})
}

func (s *server) transferGroupOwner(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	var input struct {
		UserID uint64 `json:"userId"`
	}
	if !decodeJSON(w, r, &input) || input.UserID == 0 {
		writeJSON(w, 400, response{Code: 10400, Message: "成员参数不正确"})
		return
	}
	if err := s.chats.TransferOwner(r.Context(), claims.UserID, r.PathValue("key"), input.UserID); err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "群主已转让"})
}

func (s *server) groupDetails(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	item, err := s.chats.GetGroup(r.Context(), claims.UserID, r.PathValue("key"))
	if err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: item})
}

func (s *server) updateGroup(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	var input struct {
		AvatarAssetKey      string `json:"avatarAssetKey"`
		Announcement        string `json:"announcement"`
		JoinMode            string `json:"joinMode"`
		MemberInviteEnabled bool   `json:"memberInviteEnabled"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if len([]rune(input.Announcement)) > 500 || (input.JoinMode != "direct" && input.JoinMode != "approval") {
		writeJSON(w, 400, response{Code: 10400, Message: "群资料参数不正确"})
		return
	}
	err := s.chats.UpdateGroup(r.Context(), claims.UserID, r.PathValue("key"), chat.GroupSettings{
		AvatarAssetKey: input.AvatarAssetKey, Announcement: input.Announcement,
		JoinMode: input.JoinMode, MemberInviteEnabled: input.MemberInviteEnabled,
	})
	if err != nil {
		writeGroupError(w, err)
		return
	}
	group, err := s.chats.GetGroup(r.Context(), claims.UserID, r.PathValue("key"))
	if err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: group})
}

func (s *server) groupMembers(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	items, err := s.chats.ListMembers(r.Context(), claims.UserID, r.PathValue("key"))
	if err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: items})
}

func (s *server) inviteGroupMember(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	var input struct {
		UserID uint64 `json:"userId"`
	}
	if !decodeJSON(w, r, &input) || input.UserID == 0 {
		writeJSON(w, 400, response{Code: 10400, Message: "成员参数不正确"})
		return
	}
	if err := s.chats.InviteMember(r.Context(), claims.UserID, r.PathValue("key"), input.UserID); err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func (s *server) setGroupMemberRole(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	targetID, err := strconv.ParseUint(r.PathValue("userID"), 10, 64)
	if err != nil {
		writeJSON(w, 400, response{Code: 10400, Message: "成员参数不正确"})
		return
	}
	var input struct {
		Role string `json:"role"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if err := s.chats.SetMemberRole(r.Context(), claims.UserID, r.PathValue("key"), targetID, input.Role); err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func (s *server) setGroupMemberMute(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	targetID, err := strconv.ParseUint(r.PathValue("userID"), 10, 64)
	if err != nil {
		writeJSON(w, 400, response{Code: 10400, Message: "成员参数不正确"})
		return
	}
	var input struct {
		MutedUntil *time.Time `json:"mutedUntil"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if err := s.chats.SetMemberMute(r.Context(), claims.UserID, r.PathValue("key"), targetID, input.MutedUntil); err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func (s *server) removeGroupMember(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	targetID, err := strconv.ParseUint(r.PathValue("userID"), 10, 64)
	if err != nil {
		writeJSON(w, 400, response{Code: 10400, Message: "成员参数不正确"})
		return
	}
	if err := s.chats.RemoveMember(r.Context(), claims.UserID, r.PathValue("key"), targetID); err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func (s *server) listJoinRequests(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	items, err := s.chats.ListJoinRequests(r.Context(), claims.UserID, r.PathValue("key"))
	if err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: items})
}

func (s *server) resolveJoinRequest(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	requestID, err := strconv.ParseUint(r.PathValue("id"), 10, 64)
	if err != nil {
		writeJSON(w, 400, response{Code: 10400, Message: "申请参数不正确"})
		return
	}
	var input struct {
		Accept bool `json:"accept"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if err := s.chats.ResolveJoinRequest(r.Context(), claims.UserID, r.PathValue("key"), requestID, input.Accept); err != nil {
		writeGroupError(w, err)
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func (s *server) listMessages(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	if err := s.chats.EnsureDefaults(r.Context(), claims.UserID); err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "初始化会话失败"})
		return
	}
	beforeID, _ := strconv.ParseUint(r.URL.Query().Get("beforeId"), 10, 64)
	items, err := s.chats.ListMessages(r.Context(), claims.UserID, r.PathValue("key"), beforeID, 50)
	if errors.Is(err, chat.ErrNotFound) {
		writeJSON(w, 404, response{Code: 10404, Message: "会话不存在"})
		return
	}
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取消息失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: items})
}

func (s *server) createMessage(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	var input struct {
		Type             string `json:"type"`
		Content          string `json:"content"`
		ClientMessageID  string `json:"clientMessageId"`
		ReplyToMessageID uint64 `json:"replyToMessageId"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	input.Type = strings.TrimSpace(input.Type)
	input.Content = strings.TrimSpace(input.Content)
	if input.Content == "" || !validMessageType(input.Type) || len(input.Content) > 5000 || len(input.ClientMessageID) > 64 {
		writeJSON(w, 400, response{Code: 10400, Message: "消息内容或类型不正确"})
		return
	}
	if err := s.chats.EnsureDefaults(r.Context(), claims.UserID); err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "初始化会话失败"})
		return
	}
	user, err := s.accounts.ByID(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, 404, response{Code: 10404, Message: "用户不存在"})
		return
	}
	message, err := s.chats.CreateMessage(r.Context(), claims.UserID, r.PathValue("key"), user.Nickname, input.Type, input.Content, input.ClientMessageID, input.ReplyToMessageID)
	if errors.Is(err, chat.ErrNotFound) {
		writeJSON(w, 404, response{Code: 10404, Message: "会话或回复消息不存在"})
		return
	}
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "发送消息失败"})
		return
	}
	writeJSON(w, 201, response{Code: 0, Message: "ok", Data: message})
}

func (s *server) markConversationRead(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	var input struct {
		MessageID uint64 `json:"messageId"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if input.MessageID == 0 {
		writeJSON(w, 400, response{Code: 10400, Message: "消息 ID 不能为空"})
		return
	}
	if err := s.chats.MarkRead(r.Context(), claims.UserID, r.PathValue("key"), input.MessageID); errors.Is(err, chat.ErrNotFound) {
		writeJSON(w, 404, response{Code: 10404, Message: "会话或消息不存在"})
		return
	} else if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "更新已读状态失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func (s *server) markAllConversationsRead(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	if err := s.chats.MarkAllRead(r.Context(), claims.UserID); err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "更新已读状态失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func (s *server) searchUsers(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	keyword := strings.TrimSpace(r.URL.Query().Get("q"))
	if len([]rune(keyword)) < 2 {
		writeJSON(w, 400, response{Code: 10400, Message: "请输入至少 2 个字符"})
		return
	}
	items, err := s.friends.Search(r.Context(), claims.UserID, keyword)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "搜索用户失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: items})
}

func (s *server) listFriends(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	items, err := s.friends.List(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取联系人失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: items})
}

func (s *server) listFriendRequests(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	items, err := s.friends.Incoming(r.Context(), claims.UserID)
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "读取好友申请失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok", Data: items})
}

func (s *server) sendFriendRequest(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	var input struct {
		UserID uint64 `json:"userId"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if input.UserID == 0 {
		writeJSON(w, 400, response{Code: 10400, Message: "用户 ID 不能为空"})
		return
	}
	err := s.friends.Send(r.Context(), claims.UserID, input.UserID)
	if errors.Is(err, friend.ErrNotFound) {
		writeJSON(w, 404, response{Code: 10404, Message: "用户不存在"})
		return
	}
	if errors.Is(err, friend.ErrConflict) {
		writeJSON(w, 409, response{Code: 10409, Message: "已是好友、申请已存在或对方已申请添加你"})
		return
	}
	if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "发送好友申请失败"})
		return
	}
	writeJSON(w, 201, response{Code: 0, Message: "好友申请已发送"})
}

func (s *server) acceptFriendRequest(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	s.respondToFriendRequest(w, r, claims, true)
}

func (s *server) rejectFriendRequest(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
	s.respondToFriendRequest(w, r, claims, false)
}

func (s *server) respondToFriendRequest(w http.ResponseWriter, r *http.Request, claims auth.Claims, accept bool) {
	requestID, err := strconv.ParseUint(r.PathValue("id"), 10, 64)
	if err != nil || requestID == 0 {
		writeJSON(w, 400, response{Code: 10400, Message: "好友申请 ID 不正确"})
		return
	}
	if err = s.friends.Respond(r.Context(), claims.UserID, requestID, accept); errors.Is(err, friend.ErrNotFound) {
		writeJSON(w, 404, response{Code: 10404, Message: "好友申请不存在或已处理"})
		return
	} else if err != nil {
		writeJSON(w, 500, response{Code: 10500, Message: "处理好友申请失败"})
		return
	}
	writeJSON(w, 200, response{Code: 0, Message: "ok"})
}

func validMessageType(value string) bool {
	return value == "text" || value == "image" || value == "video" || value == "content"
}
func (s *server) requireAuth(next func(http.ResponseWriter, *http.Request, auth.Claims)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, err := auth.BearerToken(r.Header.Get("Authorization"))
		if err != nil {
			writeJSON(w, 401, response{Code: 10101, Message: "请先登录"})
			return
		}
		claims, err := s.tokens.Parse(token)
		if err != nil {
			writeJSON(w, 401, response{Code: 10102, Message: "登录已失效"})
			return
		}
		next(w, r, claims)
	}
}

func (s *server) requireAdmin(next func(http.ResponseWriter, *http.Request, auth.Claims)) http.HandlerFunc {
	return s.requireAuth(func(w http.ResponseWriter, r *http.Request, claims auth.Claims) {
		if claims.Role != "admin" {
			writeJSON(w, 403, response{Code: 10103, Message: "无管理员权限"})
			return
		}
		next(w, r, claims)
	})
}

func publicUser(u account.User) userData {
	return userData{ID: u.ID, Email: u.Email, Phone: u.Phone, Nickname: u.Nickname, AvatarURL: u.AvatarURL, Role: u.Role}
}
func decodeJSON(w http.ResponseWriter, r *http.Request, value any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if decoder.Decode(value) != nil {
		writeJSON(w, 400, response{Code: 10400, Message: "请求参数错误"})
		return false
	}
	return true
}
func writeJSON(w http.ResponseWriter, status int, body response) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if isLocalDevelopmentOrigin(origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func isLocalDevelopmentOrigin(origin string) bool {
	return strings.HasPrefix(origin, "http://localhost:") ||
		strings.HasPrefix(origin, "http://127.0.0.1:") ||
		origin == "http://localhost" || origin == "http://127.0.0.1"
}
