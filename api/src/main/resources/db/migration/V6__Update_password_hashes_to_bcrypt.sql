-- Migrate password hashes from SHA-256 to bcrypt
-- All dev users with password 'password123' (old SHA-256 hash: 75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=)
-- All dev users with password 'test123' (old SHA-256 hash: 7NcYcNGWMxapfjrDQIyYNa2M8PPBvHA1J8MCZVNPda4=)

UPDATE persons SET password_hash = '$2a$12$LzTSFLF38dCLoZmLlWTMf.aZvcV.u5.R5.PClzWyK0hBPQtDALHIC'
WHERE password_hash = '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=';

UPDATE persons SET password_hash = '$2a$12$lByhxzqwAQrGPZqdki.ka.mgGIMTHqmPJJXyrxpnvdW.AXLbclK.S'
WHERE password_hash = '7NcYcNGWMxapfjrDQIyYNa2M8PPBvHA1J8MCZVNPda4=';

UPDATE users SET password_hash = '$2a$12$LzTSFLF38dCLoZmLlWTMf.aZvcV.u5.R5.PClzWyK0hBPQtDALHIC'
WHERE password_hash = '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=';

UPDATE users SET password_hash = '$2a$12$lByhxzqwAQrGPZqdki.ka.mgGIMTHqmPJJXyrxpnvdW.AXLbclK.S'
WHERE password_hash = '7NcYcNGWMxapfjrDQIyYNa2M8PPBvHA1J8MCZVNPda4=';
