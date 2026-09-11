ALTER TABLE conversations
    ADD COLUMN owner_user_id BIGINT UNSIGNED NULL AFTER member_count,
    ADD COLUMN avatar_asset_key VARCHAR(120) NOT NULL DEFAULT '' AFTER owner_user_id,
    ADD COLUMN announcement VARCHAR(500) NOT NULL DEFAULT '' AFTER avatar_asset_key,
    ADD COLUMN join_mode ENUM('direct','approval') NOT NULL DEFAULT 'direct' AFTER announcement,
    ADD COLUMN member_invite_enabled TINYINT(1) NOT NULL DEFAULT 1 AFTER join_mode;

UPDATE conversations c
JOIN (
    SELECT conversation_id, MIN(user_id) AS owner_user_id
    FROM conversation_members
    GROUP BY conversation_id
) members ON members.conversation_id = c.id
SET c.owner_user_id = members.owner_user_id
WHERE c.type = 'group' AND c.owner_user_id IS NULL;

ALTER TABLE conversations
    ADD KEY idx_conversations_owner (owner_user_id),
    ADD CONSTRAINT fk_conversations_owner
        FOREIGN KEY (owner_user_id) REFERENCES users (id) ON DELETE RESTRICT;

ALTER TABLE conversation_members
    ADD COLUMN role ENUM('owner','admin','member') NOT NULL DEFAULT 'member' AFTER user_id,
    ADD COLUMN muted_until DATETIME(3) NULL AFTER muted;

UPDATE conversation_members cm
JOIN conversations c ON c.id = cm.conversation_id AND c.owner_user_id = cm.user_id
SET cm.role = 'owner'
WHERE c.type = 'group';

CREATE TABLE IF NOT EXISTS group_join_requests (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    conversation_id BIGINT UNSIGNED NOT NULL,
    applicant_user_id BIGINT UNSIGNED NOT NULL,
    inviter_user_id BIGINT UNSIGNED NULL,
    status ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    handled_at DATETIME(3) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_group_join_pending (conversation_id, applicant_user_id, status),
    KEY idx_group_join_requests_conversation (conversation_id, status),
    CONSTRAINT fk_group_join_requests_conversation
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE,
    CONSTRAINT fk_group_join_requests_applicant
        FOREIGN KEY (applicant_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_group_join_requests_inviter
        FOREIGN KEY (inviter_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
