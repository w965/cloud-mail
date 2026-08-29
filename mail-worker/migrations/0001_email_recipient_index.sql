CREATE TABLE IF NOT EXISTS email_recipient (
    email_id INTEGER NOT NULL,
    address TEXT NOT NULL COLLATE NOCASE,
    PRIMARY KEY (email_id, address)
) WITHOUT ROWID;

CREATE TRIGGER IF NOT EXISTS trg_email_recipient_insert
AFTER INSERT ON email
BEGIN
    INSERT OR IGNORE INTO email_recipient (email_id, address)
    SELECT
        NEW.email_id,
        trim(json_extract(recipient_item.value, '$.address'))
    FROM json_each(
        CASE
            WHEN json_valid(NEW.recipient) THEN
                CASE
                    WHEN json_type(NEW.recipient) = 'array' THEN NEW.recipient
                    ELSE '[]'
                END
            ELSE '[]'
        END
    ) AS recipient_item
    WHERE recipient_item.type = 'object'
        AND json_type(recipient_item.value, '$.address') = 'text'
        AND trim(json_extract(recipient_item.value, '$.address')) <> '';
END;

CREATE TRIGGER IF NOT EXISTS trg_email_recipient_update
AFTER UPDATE OF recipient, email_id ON email
BEGIN
    DELETE FROM email_recipient WHERE email_id = OLD.email_id;
    INSERT OR IGNORE INTO email_recipient (email_id, address)
    SELECT
        NEW.email_id,
        trim(json_extract(recipient_item.value, '$.address'))
    FROM json_each(
        CASE
            WHEN json_valid(NEW.recipient) THEN
                CASE
                    WHEN json_type(NEW.recipient) = 'array' THEN NEW.recipient
                    ELSE '[]'
                END
            ELSE '[]'
        END
    ) AS recipient_item
    WHERE recipient_item.type = 'object'
        AND json_type(recipient_item.value, '$.address') = 'text'
        AND trim(json_extract(recipient_item.value, '$.address')) <> '';
END;

CREATE TRIGGER IF NOT EXISTS trg_email_recipient_delete
AFTER DELETE ON email
BEGIN
    DELETE FROM email_recipient WHERE email_id = OLD.email_id;
END;

INSERT OR IGNORE INTO email_recipient (email_id, address)
SELECT
    email.email_id,
    trim(json_extract(recipient_item.value, '$.address'))
FROM email
JOIN json_each(
    CASE
        WHEN json_valid(email.recipient) THEN
            CASE
                WHEN json_type(email.recipient) = 'array' THEN email.recipient
                ELSE '[]'
            END
        ELSE '[]'
    END
) AS recipient_item
WHERE recipient_item.type = 'object'
    AND json_type(recipient_item.value, '$.address') = 'text'
    AND trim(json_extract(recipient_item.value, '$.address')) <> '';

CREATE INDEX IF NOT EXISTS idx_email_recipient_address_email_id
ON email_recipient(address COLLATE NOCASE, email_id DESC);
