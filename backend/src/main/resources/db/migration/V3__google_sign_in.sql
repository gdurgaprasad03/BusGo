-- Google sign-in support.
--  * google_sub: Google's stable, unique id for the person (the "sub" claim of a verified ID token).
--  * phone becomes optional, because a Google account does not give us a mobile number.
ALTER TABLE users MODIFY phone VARCHAR(15) NULL;
ALTER TABLE users ADD COLUMN google_sub VARCHAR(64) NULL;
ALTER TABLE users ADD CONSTRAINT uq_users_google_sub UNIQUE (google_sub);
