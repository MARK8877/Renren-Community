package main

import "testing"

func TestLoadImportConfigRequiresShareURL(t *testing.T) {
	t.Setenv("QUARK_SHARE_URL", "")
	if _, err := loadImportConfig(); err == nil {
		t.Fatal("loadImportConfig() succeeded without QUARK_SHARE_URL")
	}
}

func TestLoadImportConfigRejectsInvalidLimit(t *testing.T) {
	t.Setenv("QUARK_SHARE_URL", "https://pan.quark.cn/s/demo")
	t.Setenv("QUARK_IMPORT_LIMIT", "0")
	if _, err := loadImportConfig(); err == nil {
		t.Fatal("loadImportConfig() accepted zero limit")
	}
}
