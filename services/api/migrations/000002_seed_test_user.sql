-- 本地开发测试账号，仅用于开发环境。
-- 账号：test@example.com
-- 密码：Test123456!
INSERT INTO users (email, phone, password_hash, nickname, role, status)
VALUES (
    'test@example.com',
    NULL,
    '$2y$12$7zgpbQb93H8d0.w.AosjLu50rDLj5YPEdOuhl0jhciv76cH.iLzRm',
    '测试用户',
    'user',
    'active'
)
ON DUPLICATE KEY UPDATE
    password_hash = VALUES(password_hash),
    nickname = VALUES(nickname),
    role = 'user',
    status = 'active';
