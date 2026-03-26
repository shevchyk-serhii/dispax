-- Fix BCrypt hashes for password123
-- The previous hash was not generated from 'password123'
-- Correct hash: $2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S

UPDATE users
   SET password_hash = '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S'
 WHERE password_hash = '$2a$12$LzTSFLF38dCLoZmLlWTMf.aZvcV.u5.R5.PClzWyK0hBPQtDALHIC';

UPDATE persons
   SET password_hash = '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S'
 WHERE password_hash = '$2a$12$LzTSFLF38dCLoZmLlWTMf.aZvcV.u5.R5.PClzWyK0hBPQtDALHIC';
