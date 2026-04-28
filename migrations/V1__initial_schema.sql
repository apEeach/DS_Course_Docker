-- V1__initial_schema.sql
-- 课程培训平台初始数据库结构（19 张表）
-- 基于 docs/db.md 设计文档，MySQL 8.0 兼容

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 1. staff_accounts（后台工作人员账号）
-- ============================================================
CREATE TABLE IF NOT EXISTS `staff_accounts` (
    `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `username`     VARCHAR(64)     NOT NULL COMMENT '登录账号，唯一',
    `password_hash` VARCHAR(255)   NOT NULL COMMENT '密码哈希',
    `display_name`  VARCHAR(64)     NOT NULL COMMENT '显示名称',
    `phone`         VARCHAR(20)     DEFAULT NULL COMMENT '手机号',
    `wechat_id`     VARCHAR(64)     DEFAULT NULL COMMENT '微信号',
    `wechat_name`   VARCHAR(64)     DEFAULT NULL COMMENT '微信昵称',
    `role`          ENUM('admin','operations','sales','finance','lecturer') NOT NULL COMMENT '账号角色',
    `status`       ENUM('enabled','disabled') NOT NULL DEFAULT 'enabled' COMMENT '账号状态',
    `created_at`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台工作人员账号';

-- ============================================================
-- 2. customers（学员）
-- ============================================================
CREATE TABLE IF NOT EXISTS `customers` (
    `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `wechat_openid`    VARCHAR(128)    NOT NULL COMMENT '微信OpenID，唯一',
    `wechat_unionid`   VARCHAR(128)    DEFAULT NULL COMMENT '微信UnionID',
    `nickname`         VARCHAR(128)    DEFAULT NULL COMMENT '昵称',
    `avatar_url`       VARCHAR(512)    DEFAULT NULL COMMENT '头像地址',
    `source`           ENUM('wechat_mini_program','manual_import') NOT NULL COMMENT '注册来源',
    `bound_sales_id`   BIGINT UNSIGNED DEFAULT NULL COMMENT '绑定业务员ID',
    `purchase_count`   INT             NOT NULL DEFAULT 0 COMMENT '购买次数（成功支付并核销的订单数，冗余字段）',
    `registered_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
    `created_at`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_wechat_openid` (`wechat_openid`),
    KEY `idx_bound_sales` (`bound_sales_id`),
    CONSTRAINT `fk_customers_sales` FOREIGN KEY (`bound_sales_id`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='C端学员用户';

-- ============================================================
-- 3. customer_profiles（学员资料）
-- ============================================================
CREATE TABLE IF NOT EXISTS `customer_profiles` (
    `customer_id`           BIGINT UNSIGNED NOT NULL COMMENT '主键，关联客户ID',
    `douyin_id`             VARCHAR(128)    DEFAULT NULL COMMENT '抖音号',
    `monthly_income_range`  VARCHAR(64)     DEFAULT NULL COMMENT '月收入区间',
    `learning_goal`         VARCHAR(512)    DEFAULT NULL COMMENT '学习目标',
    `customer_source`       VARCHAR(64)     DEFAULT NULL COMMENT '客户来源（直播间加好友/别人介绍等），由业务员填写',
    `remark`                VARCHAR(512)    DEFAULT NULL COMMENT '备注',
    `profile_completed_at`  DATETIME        DEFAULT NULL COMMENT '信息完善时间',
    `created_at`            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`customer_id`),
    CONSTRAINT `fk_profiles_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='学员上课资料';

-- ============================================================
-- 4. course_categories（课程分类）
-- ============================================================
CREATE TABLE IF NOT EXISTS `course_categories` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name`       VARCHAR(64)     NOT NULL COMMENT '分类名称，唯一',
    `sort_order` INT             NOT NULL DEFAULT 0 COMMENT '排序优先级',
    `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课程分类';

-- ============================================================
-- 5. courses（课程主数据）
-- ============================================================
CREATE TABLE IF NOT EXISTS `courses` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name`                 VARCHAR(128)    NOT NULL COMMENT '课程名称',
    `intro`                TEXT            DEFAULT NULL COMMENT '课程简介',
    `cover_image_url`      VARCHAR(512)    DEFAULT NULL COMMENT '封面图URL',
    `category_id`          BIGINT UNSIGNED DEFAULT NULL COMMENT '课程分类ID',
    `sort_priority`        INT             NOT NULL DEFAULT 0 COMMENT '排序优先级',
    `status`               ENUM('draft','online','offline') NOT NULL DEFAULT 'draft' COMMENT '课程状态',
    `total_revenue_amount` DECIMAL(12,2)   NOT NULL DEFAULT 0.00 COMMENT '课程总收入（该课程下所有已核销订单的金额汇总，自动更新）',
    `created_by`           BIGINT UNSIGNED DEFAULT NULL COMMENT '创建人（后台账号）',
    `created_at`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_category_id` (`category_id`),
    KEY `idx_status` (`status`),
    CONSTRAINT `fk_courses_category` FOREIGN KEY (`category_id`) REFERENCES `course_categories`(`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_courses_creator` FOREIGN KEY (`created_by`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课程主数据';

-- ============================================================
-- 6. course_sessions（课期）
-- ============================================================
CREATE TABLE IF NOT EXISTS `course_sessions` (
    `id`                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `course_id`             BIGINT UNSIGNED NOT NULL COMMENT '所属课程ID',
    `name`                  VARCHAR(128)    NOT NULL COMMENT '课期名称',
    `lecturer_id`           BIGINT UNSIGNED DEFAULT NULL COMMENT '讲师ID',
    `location`              VARCHAR(255)    DEFAULT NULL COMMENT '上课地点',
    `start_time`            DATETIME        NOT NULL COMMENT '开始时间',
    `end_time`              DATETIME        NOT NULL COMMENT '结束时间',
    `registration_deadline` DATETIME        DEFAULT NULL COMMENT '报名截止时间',
    `capacity`              INT             NOT NULL DEFAULT 0 COMMENT '容量上限',
    `enrolled_count`        INT             NOT NULL DEFAULT 0 COMMENT '已报名名额数（汇总）',
    `price_amount`          DECIMAL(10,2)   NOT NULL COMMENT '单价',
    `per_user_slot_limit`   INT             NOT NULL DEFAULT 1 COMMENT '单人购课上限',
    `status`                ENUM('not_started','open_for_registration','registration_closed','in_progress','finished','cancelled') NOT NULL DEFAULT 'not_started' COMMENT '课期状态',
    `checkin_verify_url`    VARCHAR(512)    DEFAULT NULL COMMENT '签到核验链接',
    `created_by`            BIGINT UNSIGNED DEFAULT NULL COMMENT '创建人',
    `created_at`            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_course_id` (`course_id`),
    KEY `idx_status` (`status`),
    KEY `idx_lecturer_status` (`lecturer_id`, `status`) COMMENT '讲师查询自己授课课期',
    CONSTRAINT `fk_sessions_course` FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_sessions_lecturer` FOREIGN KEY (`lecturer_id`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_sessions_creator` FOREIGN KEY (`created_by`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课期';

-- ============================================================
-- 7. session_segments（课期场次）
-- ============================================================
CREATE TABLE IF NOT EXISTS `session_segments` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `session_id`    BIGINT UNSIGNED NOT NULL COMMENT '课期ID',
    `segment_name`  VARCHAR(64)     NOT NULL COMMENT '场次名称',
    `starts_at`     DATETIME        DEFAULT NULL COMMENT '场次开始时间',
    `ends_at`       DATETIME        DEFAULT NULL COMMENT '场次结束时间',
    `sort_order`    INT             NOT NULL DEFAULT 0 COMMENT '场次排序',
    `is_default_all` TINYINT(1)     NOT NULL DEFAULT 1 COMMENT '是否默认全场次',
    `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_session_id` (`session_id`),
    CONSTRAINT `fk_segments_session` FOREIGN KEY (`session_id`) REFERENCES `course_sessions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课期场次';

-- ============================================================
-- 8. orders（统一订单）
-- ============================================================
CREATE TABLE IF NOT EXISTS `orders` (
    `id`                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_no`              VARCHAR(64)     NOT NULL COMMENT '订单号，唯一',
    `customer_id`           BIGINT UNSIGNED NOT NULL COMMENT '下单客户ID',
    `session_id`            BIGINT UNSIGNED NOT NULL COMMENT '课期ID',
    `type`                  ENUM('purchase','recharge') NOT NULL COMMENT '订单类型（购课/充值）',
    `source`                ENUM('mini_program','offline') NOT NULL COMMENT '订单来源',
    `slot_quantity`         INT             NOT NULL COMMENT '名额数量',
    `unit_price_amount`     DECIMAL(10,2)   NOT NULL COMMENT '单价',
    `total_amount`          DECIMAL(10,2)   NOT NULL COMMENT '总金额',
    `status`                ENUM('pending_payment','paid','verified','rejected','refunding','refunded','closed') NOT NULL DEFAULT 'pending_payment' COMMENT '订单状态',
    `payment_deadline_at`   DATETIME        DEFAULT NULL COMMENT '支付截止时间',
    `paid_at`               DATETIME        DEFAULT NULL COMMENT '支付时间（小程序订单由支付回调写入；线下订单由业务员填写客户实际转账/付款时间，复用此字段记录线下收款时间）',
    `verified_at`           DATETIME        DEFAULT NULL COMMENT '核销时间',
    `verified_by`           BIGINT UNSIGNED DEFAULT NULL COMMENT '财务核销人（线下单）',
    `rejected_reason`       VARCHAR(512)    DEFAULT NULL COMMENT '拒绝原因',
    `external_payment_no`   VARCHAR(128)    DEFAULT NULL COMMENT '线下支付单号',
    `payment_proof_url`     VARCHAR(512)    DEFAULT NULL COMMENT '线下付款凭证',
    `created_by_staff_id`   BIGINT UNSIGNED DEFAULT NULL COMMENT '线下订单创建人（业务员）',
    `created_at`            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_order_no` (`order_no`),
    KEY `idx_customer_created` (`customer_id`, `created_at`) COMMENT 'PRD §3.1.4 我的订单：按创建时间倒序列表',
    KEY `idx_session_id` (`session_id`),
    KEY `idx_status_created` (`status`, `created_at`) COMMENT '支付超时订单自动关闭、按状态过滤查询',
    CONSTRAINT `fk_orders_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_orders_session` FOREIGN KEY (`session_id`) REFERENCES `course_sessions`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_orders_verifier` FOREIGN KEY (`verified_by`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_orders_staff_creator` FOREIGN KEY (`created_by_staff_id`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='统一订单（购课/充值）';

-- ============================================================
-- 9. payment_records（支付流水）
-- ============================================================
CREATE TABLE IF NOT EXISTS `payment_records` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `order_id`          BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
    `payment_no`        VARCHAR(64)     NOT NULL COMMENT '支付流水号，唯一',
    `channel`           ENUM('wechat_pay','offline_cash','offline_transfer') NOT NULL COMMENT '支付渠道',
    `channel_trade_no`  VARCHAR(128)    DEFAULT NULL COMMENT '渠道交易单号',
    `amount`            DECIMAL(10,2)   NOT NULL COMMENT '本次支付金额',
    `status`            ENUM('pending','success','failed','closed') NOT NULL DEFAULT 'pending' COMMENT '支付状态',
    `paid_at`           DATETIME        DEFAULT NULL COMMENT '到账时间',
    `failed_reason`     VARCHAR(512)    DEFAULT NULL COMMENT '失败原因',
    `callback_payload`  JSON            DEFAULT NULL COMMENT '回调原始报文',
    `created_at`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_payment_no` (`payment_no`),
    KEY `idx_order_id` (`order_id`),
    CONSTRAINT `fk_payments_order` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='支付流水';

-- ============================================================
-- 10. registrations（报名汇总）
-- ============================================================
CREATE TABLE IF NOT EXISTS `registrations` (
    `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `customer_id`    BIGINT UNSIGNED NOT NULL COMMENT '客户ID',
    `session_id`     BIGINT UNSIGNED NOT NULL COMMENT '课期ID',
    `sales_agent_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '根业务员归属ID',
    `total_slots`    INT             NOT NULL DEFAULT 0 COMMENT '总名额数',
    `active_slots`   INT             NOT NULL DEFAULT 0 COMMENT '当前有效名额数',
    `status`         ENUM('active','cleared','cancelled') NOT NULL DEFAULT 'active' COMMENT '汇总状态',
    `created_at`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_customer_session` (`customer_id`,`session_id`),
    KEY `idx_session_id` (`session_id`),
    KEY `idx_sales_agent` (`sales_agent_id`) COMMENT '业务员业绩统计查询',
    CONSTRAINT `fk_registrations_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_registrations_session` FOREIGN KEY (`session_id`) REFERENCES `course_sessions`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_registrations_agent` FOREIGN KEY (`sales_agent_id`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='报名汇总（客户+课期）';

-- ============================================================
-- 11. registration_slots（名额明细）
-- ============================================================
CREATE TABLE IF NOT EXISTS `registration_slots` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `registration_id`   BIGINT UNSIGNED NOT NULL COMMENT '所属报名汇总ID',
    `session_id`        BIGINT UNSIGNED NOT NULL COMMENT '课期ID',
    `owner_customer_id` BIGINT UNSIGNED NOT NULL COMMENT '当前持有人ID',
    `sales_agent_id`    BIGINT UNSIGNED DEFAULT NULL COMMENT '根业务员归属ID',
    `root_order_id`     BIGINT UNSIGNED NOT NULL COMMENT '来源订单ID',
    `root_customer_id`  BIGINT UNSIGNED NOT NULL COMMENT '原始购买人ID',
    `status`            ENUM('active','refunded','cancelled') NOT NULL DEFAULT 'active' COMMENT '名额状态',
    `gift_level`        TINYINT         NOT NULL DEFAULT 0 COMMENT '转赠层级（0未转赠，1已转赠）',
    `gift_status`       TINYINT         NOT NULL DEFAULT 0 COMMENT '转赠状态（0=可转赠, 1=转赠中, 2=已转赠）',
    `gifted_at`         DATETIME        DEFAULT NULL COMMENT '转赠完成时间',
    `refunded_at`       DATETIME        DEFAULT NULL COMMENT '退款完成时间',
    `cancelled_at`      DATETIME        DEFAULT NULL COMMENT '取消时间',
    `created_at`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_registration_id` (`registration_id`),
    KEY `idx_session_id` (`session_id`),
    KEY `idx_owner_customer_id` (`owner_customer_id`),
    KEY `idx_root_order_id` (`root_order_id`),
    KEY `idx_root_customer` (`root_customer_id`),
    KEY `idx_status` (`status`),
    KEY `idx_refund_filter` (`root_order_id`, `owner_customer_id`, `root_customer_id`, `status`, `gift_level`, `gift_status`) COMMENT '退款名额筛选复合索引：PRD §4.6 已核销订单可退款名额查询',
    CONSTRAINT `fk_slots_registration` FOREIGN KEY (`registration_id`) REFERENCES `registrations`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_slots_session` FOREIGN KEY (`session_id`) REFERENCES `course_sessions`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_slots_owner` FOREIGN KEY (`owner_customer_id`) REFERENCES `customers`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_slots_agent` FOREIGN KEY (`sales_agent_id`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_slots_root_order` FOREIGN KEY (`root_order_id`) REFERENCES `orders`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_slots_root_customer` FOREIGN KEY (`root_customer_id`) REFERENCES `customers`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='名额明细';

-- ============================================================
-- 12. refunds（退款主单）
-- ============================================================
CREATE TABLE IF NOT EXISTS `refunds` (
    `id`                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `refund_no`             VARCHAR(64)     NOT NULL COMMENT '退款单号，唯一',
    `order_id`              BIGINT UNSIGNED NOT NULL COMMENT '关联订单ID',
    `applicant_customer_id` BIGINT UNSIGNED NOT NULL COMMENT '申请客户ID（小程序申请/后台发起均必填）',
    `source`                ENUM('customer','staff') NOT NULL COMMENT '退款来源（客户申请/后台发起）',
    `type`                  ENUM('full','partial') NOT NULL COMMENT '退款类型（全额/部分）',
    `channel`               ENUM('wechat_original_route','offline_manual') NOT NULL COMMENT '退款渠道',
    `status`                ENUM('pending','approved','rejected','completed','cancelled') NOT NULL DEFAULT 'pending' COMMENT '退款状态',
    `amount`                DECIMAL(10,2)   NOT NULL COMMENT '退款金额',
    `reason`                VARCHAR(512)    DEFAULT NULL COMMENT '退款原因',
    `handled_by`            BIGINT UNSIGNED DEFAULT NULL COMMENT '财务处理人ID',
    `handled_at`            DATETIME        DEFAULT NULL COMMENT '处理时间',
    `idempotency_key`       VARCHAR(128)    DEFAULT NULL COMMENT '退款幂等键',
    `rejected_reason`       VARCHAR(512)    DEFAULT NULL COMMENT '退款拒绝原因',
    `created_at`            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`            DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_refund_no` (`refund_no`),
    UNIQUE KEY `uk_idempotency_key` (`idempotency_key`),
    KEY `idx_refund_dedup` (`order_id`,`applicant_customer_id`,`created_at`) COMMENT '退款业务去重：5 分钟窗口内查 pending 退款；覆盖 (order_id) 和 (order_id, applicant_customer_id) 查询',
    KEY `idx_status_created` (`status`, `created_at`) COMMENT '财务待处理退款列表查询，同时覆盖 idx_status(status) 查询',
    CONSTRAINT `fk_refunds_order` FOREIGN KEY (`order_id`) REFERENCES `orders`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_refunds_applicant` FOREIGN KEY (`applicant_customer_id`) REFERENCES `customers`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_refunds_handler` FOREIGN KEY (`handled_by`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='退款主单';

-- ============================================================
-- 13. refund_items（退款名额明细）
-- ============================================================
CREATE TABLE IF NOT EXISTS `refund_items` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `refund_id`            BIGINT UNSIGNED NOT NULL COMMENT '退款主单ID',
    `registration_slot_id` BIGINT UNSIGNED NOT NULL COMMENT '退款名额ID',
    `amount`               DECIMAL(10,2)   NOT NULL COMMENT '该名额退款金额',
    `created_at`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_refund_id` (`refund_id`),
    KEY `idx_slot_id` (`registration_slot_id`),
    CONSTRAINT `fk_refund_items_refund` FOREIGN KEY (`refund_id`) REFERENCES `refunds`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_refund_items_slot` FOREIGN KEY (`registration_slot_id`) REFERENCES `registration_slots`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='退款名额明细';

-- ============================================================
-- 14. gift_records（转赠记录）
-- ============================================================
CREATE TABLE IF NOT EXISTS `gift_records` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `gift_no`              VARCHAR(64)     NOT NULL COMMENT '转赠流水号，唯一',
    `session_id`           BIGINT UNSIGNED NOT NULL COMMENT '课期ID',
    `from_customer_id`     BIGINT UNSIGNED NOT NULL COMMENT '赠送人客户ID',
    `to_customer_id`       BIGINT UNSIGNED NOT NULL COMMENT '受赠人客户ID',
    `from_registration_id` BIGINT UNSIGNED NOT NULL COMMENT '赠送方汇总ID',
    `to_registration_id`   BIGINT UNSIGNED NOT NULL COMMENT '受赠方汇总ID',
    `slot_count`           INT             NOT NULL COMMENT '转赠名额数',
    `slot_ids_snapshot`    JSON            NOT NULL COMMENT '转赠名额快照',
    `share_token`          VARCHAR(128)    DEFAULT NULL COMMENT '分享令牌，唯一',
    `status`               ENUM('pending','accepted','expired','cancelled') NOT NULL DEFAULT 'pending' COMMENT '转赠状态',
    `expires_at`           DATETIME        NOT NULL COMMENT '转赠过期时间',
    `accepted_at`          DATETIME        DEFAULT NULL COMMENT '受赠确认时间',
    `created_at`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_gift_no` (`gift_no`),
    UNIQUE KEY `uk_share_token` (`share_token`),
    KEY `idx_session_id` (`session_id`),
    KEY `idx_from_customer` (`from_customer_id`),
    KEY `idx_to_customer` (`to_customer_id`),
    KEY `idx_from_status` (`from_customer_id`, `status`) COMMENT '赠送人查看自己的转赠记录',
    KEY `idx_to_status` (`to_customer_id`, `status`) COMMENT '受赠人查看收到的转赠记录',
    KEY `idx_share_token_status` (`share_token`, `status`) COMMENT '转赠链接确认查询',
    CONSTRAINT `fk_gifts_session` FOREIGN KEY (`session_id`) REFERENCES `course_sessions`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_gifts_from_customer` FOREIGN KEY (`from_customer_id`) REFERENCES `customers`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_gifts_to_customer` FOREIGN KEY (`to_customer_id`) REFERENCES `customers`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_gifts_from_registration` FOREIGN KEY (`from_registration_id`) REFERENCES `registrations`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_gifts_to_registration` FOREIGN KEY (`to_registration_id`) REFERENCES `registrations`(`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='名额转赠记录';

-- ============================================================
-- 15. seat_groups（会场分组）
-- ============================================================
CREATE TABLE IF NOT EXISTS `seat_groups` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `session_id` BIGINT UNSIGNED NOT NULL COMMENT '课期ID',
    `group_name` VARCHAR(64)     NOT NULL COMMENT '分组名称',
    `sort_order` INT             NOT NULL DEFAULT 0 COMMENT '排序',
    `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_session_id` (`session_id`),
    CONSTRAINT `fk_seat_groups_session` FOREIGN KEY (`session_id`) REFERENCES `course_sessions`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='课期分组';

-- ============================================================
-- 16. seat_assignments（名额分组分配）
-- ============================================================
CREATE TABLE IF NOT EXISTS `seat_assignments` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `registration_slot_id` BIGINT UNSIGNED NOT NULL COMMENT '名额ID（每个名额最多分配一次）',
    `seat_group_id`        BIGINT UNSIGNED NOT NULL COMMENT '分组ID',
    `assigned_by`          BIGINT UNSIGNED DEFAULT NULL COMMENT '分配操作人',
    `assigned_at`          DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '分配时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_slot_id` (`registration_slot_id`),
    KEY `idx_group_id` (`seat_group_id`),
    CONSTRAINT `fk_seat_assignments_slot` FOREIGN KEY (`registration_slot_id`) REFERENCES `registration_slots`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_seat_assignments_group` FOREIGN KEY (`seat_group_id`) REFERENCES `seat_groups`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_seat_assignments_assigner` FOREIGN KEY (`assigned_by`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='名额分组分配';

-- ============================================================
-- 17. checkin_records（签到记录）
-- ============================================================
CREATE TABLE IF NOT EXISTS `checkin_records` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `registration_slot_id` BIGINT UNSIGNED NOT NULL COMMENT '签到名额ID',
    `session_id`           BIGINT UNSIGNED NOT NULL COMMENT '课期ID',
    `session_segment_id`   BIGINT UNSIGNED NOT NULL COMMENT '场次ID',
    `checked_in_at`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '签到时间',
    `checked_in_by`        BIGINT UNSIGNED DEFAULT NULL COMMENT '核验操作人',
    `source`               ENUM('scan','manual') NOT NULL COMMENT '签到来源（扫码/手动）',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_slot_segment` (`registration_slot_id`,`session_segment_id`),
    KEY `idx_session_id` (`session_id`),
    KEY `idx_segment_id` (`session_segment_id`),
    KEY `idx_session_checked_at` (`session_id`, `checked_in_at`) COMMENT '按课期+时间查询签到记录',
    CONSTRAINT `fk_checkin_slot` FOREIGN KEY (`registration_slot_id`) REFERENCES `registration_slots`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_checkin_session` FOREIGN KEY (`session_id`) REFERENCES `course_sessions`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_checkin_segment` FOREIGN KEY (`session_segment_id`) REFERENCES `session_segments`(`id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_checkin_operator` FOREIGN KEY (`checked_in_by`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='签到事实表';

-- ============================================================
-- 18. checkin_qr_tokens（个人签到码）
-- ============================================================
CREATE TABLE IF NOT EXISTS `checkin_qr_tokens` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `token`                VARCHAR(128)    NOT NULL COMMENT '一次性签到令牌，唯一',
    `session_id`           BIGINT UNSIGNED NOT NULL COMMENT '课期ID',
    `session_segment_id`   BIGINT UNSIGNED DEFAULT NULL COMMENT '场次ID',
    `registration_slot_id` BIGINT UNSIGNED NOT NULL COMMENT '锁定名额ID',
    `customer_id`          BIGINT UNSIGNED NOT NULL COMMENT '学员ID',
    `expires_at`           DATETIME        NOT NULL COMMENT '过期时间',
    `consumed_at`          DATETIME        DEFAULT NULL COMMENT '核验使用时间',
    `created_at`           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_token` (`token`),
    KEY `idx_session_id` (`session_id`),
    KEY `idx_customer_id` (`customer_id`),
    KEY `idx_customer_session_active` (`customer_id`, `session_id`, `consumed_at`) COMMENT '查询学员在某课期的未消耗签到码',
    CONSTRAINT `fk_qr_session` FOREIGN KEY (`session_id`) REFERENCES `course_sessions`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_qr_segment` FOREIGN KEY (`session_segment_id`) REFERENCES `session_segments`(`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_qr_slot` FOREIGN KEY (`registration_slot_id`) REFERENCES `registration_slots`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_qr_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='短时效签到码';

-- ============================================================
-- 19. audit_logs（审计日志）
-- ============================================================
CREATE TABLE IF NOT EXISTS `audit_logs` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `operator_type`     ENUM('staff','customer') NOT NULL COMMENT '操作人类型',
    `operator_staff_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '操作人ID（staff 时必填）',
    `operator_customer_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '操作人ID（customer 时必填）',
    `action`            VARCHAR(64)     NOT NULL COMMENT '操作类型',
    `target_table`      VARCHAR(64)     NOT NULL COMMENT '目标表名',
    `target_id`         BIGINT UNSIGNED NOT NULL COMMENT '目标记录ID',
    `old_value`         JSON            DEFAULT NULL COMMENT '变更前快照',
    `new_value`         JSON            DEFAULT NULL COMMENT '变更后快照',
    `remark`            VARCHAR(512)    DEFAULT NULL COMMENT '备注',
    `created_at`        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_operator_staff` (`operator_staff_id`),
    KEY `idx_operator_customer` (`operator_customer_id`),
    KEY `idx_target` (`target_table`,`target_id`),
    CONSTRAINT `fk_audit_staff` FOREIGN KEY (`operator_staff_id`) REFERENCES `staff_accounts`(`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_audit_customer` FOREIGN KEY (`operator_customer_id`) REFERENCES `customers`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='审计日志';

SET FOREIGN_KEY_CHECKS = 1;
