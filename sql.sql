CREATE TABLE `takenncs-boosting` (
	`charId` VARCHAR(50) NOT NULL COLLATE 'utf8mb3_general_ci',
	`xp` INT(11) NOT NULL DEFAULT '0',
	`finished` INT(11) NULL DEFAULT '0',
	PRIMARY KEY (`charId`) USING BTREE
)
COLLATE='utf8mb3_general_ci'
ENGINE=InnoDB
ROW_FORMAT=DYNAMIC
;
