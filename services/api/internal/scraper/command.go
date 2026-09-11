package scraper

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

type RunResult struct {
	Discovered int `json:"discovered"`
	Processed  int `json:"imported"`
}

type Command interface {
	Run(ctx context.Context) (RunResult, error)
}

type PythonCommand struct {
	apiDir     string
	pythonBin  string
	scriptPath string
	limit      int
}

func NewPythonCommand(apiDir, pythonBin, scriptPath string, limit int) *PythonCommand {
	return &PythonCommand{
		apiDir:     apiDir,
		pythonBin:  pythonBin,
		scriptPath: scriptPath,
		limit:      limit,
	}
}

func (c *PythonCommand) Run(ctx context.Context) (RunResult, error) {
	var stdout, stderr bytes.Buffer
	cmd := exec.CommandContext(ctx, c.args()[0], c.args()[1:]...)
	cmd.Dir = c.apiDir
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		message := strings.TrimSpace(stderr.String())
		if message != "" {
			return RunResult{}, fmt.Errorf("run pexels scraper: %w: %s", err, truncate(message, 2000))
		}
		return RunResult{}, fmt.Errorf("run pexels scraper: %w", err)
	}
	result, err := parseStats(stderr.String())
	if err != nil {
		return RunResult{}, fmt.Errorf("parse scraper stats: %w", err)
	}
	return result, nil
}

func (c *PythonCommand) args() []string {
	return []string{
		c.pythonBin,
		c.scriptPath,
		"--pexels",
		"--pexels-limit",
		strconv.Itoa(c.limit),
		"--import",
	}
}

func parseStats(output string) (RunResult, error) {
	lines := strings.Split(output, "\n")
	for index := len(lines) - 1; index >= 0; index-- {
		line := strings.TrimSpace(lines[index])
		if line == "" {
			continue
		}
		var payload struct {
			Discovered *int `json:"discovered"`
			Imported   *int `json:"imported"`
		}
		if err := json.Unmarshal([]byte(line), &payload); err != nil {
			continue
		}
		if payload.Discovered == nil && payload.Imported == nil {
			continue
		}
		result := RunResult{}
		if payload.Discovered != nil {
			result.Discovered = *payload.Discovered
		}
		if payload.Imported != nil {
			result.Processed = *payload.Imported
		}
		return result, nil
	}
	return RunResult{}, errors.New("no JSON statistics found on stderr")
}

func truncate(value string, limit int) string {
	if len(value) <= limit {
		return value
	}
	return value[:limit] + "..."
}
