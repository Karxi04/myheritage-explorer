# Implementation Plan - Uniform Email and Password Validation

Update all user management inputs (Login, Registration, Forgot Password, and Change Password) to enforce uniform and robust email validation and strict password policy (at least 8 characters, including at least one uppercase letter, one lowercase letter, and one special character).

## User Review Required

> [!IMPORTANT]
> The new password policy requires:
> - Minimum length of 8 characters.
> - At least one uppercase letter (`A-Z`).
> - At least one lowercase letter (`a-z`).
> - At least one special character (e.g. `!@#$%^&*(),.?":{}|<>`).

## Proposed Changes

### Authentication & User Management

#### [MODIFY] [login_page.dart](file:///C:/Users/user/StudioProjects/myheritage-explorer/lib/auth/screens/login_page.dart)
- Add robust email format validation before calling `signInWithEmailAndPassword`.

#### [MODIFY] [registration_page.dart](file:///C:/Users/user/StudioProjects/myheritage-explorer/lib/auth/screens/registration_page.dart)
- Add email format validator to email text field.
- Add strict password validator enforcing 8+ characters, uppercase, lowercase, and special character requirements.

#### [MODIFY] [change_password_page.dart](file:///C:/Users/user/StudioProjects/myheritage-explorer/lib/auth/screens/change_password_page.dart)
- Update password strength validation in `changePassword()` to enforce 8+ characters, uppercase, lowercase, and special character requirements.

#### [MODIFY] [forgot_password_page.dart](file:///C:/Users/user/StudioProjects/myheritage-explorer/lib/auth/screens/forgot_password_page.dart)
- Enhance email format validation in `sendResetLink()`.

## Verification Plan

### Automated Tests
- Build and compile check.

### Manual Verification
- Test login with invalid/valid emails.
- Test registration with weak passwords (e.g. lacking special char or uppercase) and valid passwords.
- Test change password with weak and strong passwords.
- Test forgot password with invalid email formats.
