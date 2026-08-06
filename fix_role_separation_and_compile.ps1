$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Backup-File([string]$Path) {
    if (-not (Test-Path $Path)) {
        throw "Required file was not found: $Path"
    }

    $BackupPath = "$Path.before_role_fix.bak"
    if (-not (Test-Path $BackupPath)) {
        Copy-Item $Path $BackupPath
    }
}

function Save-Text([string]$Path, [string]$Content) {
    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

Write-Host ""
Write-Host "MyHeritage role separation and compile repair" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Fix the two current compile problems.
# ---------------------------------------------------------------------------
$ForgotPath = Join-Path $ProjectRoot "lib\auth\screens\forgot_password_page.dart"
$TravelerPagesPath = Join-Path $ProjectRoot "lib\traveler\traveler_pages.dart"
$ReviewModelPath = Join-Path $ProjectRoot "lib\traveler\daily_planner\review_flag_model.dart"

Backup-File $ForgotPath
Backup-File $TravelerPagesPath
Backup-File $ReviewModelPath

$ForgotText = Get-Content $ForgotPath -Raw

# LoginPage currently calls ForgotPasswordPage(admin: true/false).
# Keep compatibility with isAdmin and role as well.
if ($ForgotText -notmatch "\bthis\.admin\s*=") {
    $ForgotText = [regex]::Replace(
        $ForgotText,
        "(const\s+ForgotPasswordPage\s*\(\s*\{\s*super\.key,\s*)",
        "`$1`r`n    this.admin = false,",
        1
    )
}

if ($ForgotText -notmatch "final\s+bool\s+admin\s*;") {
    $ForgotText = [regex]::Replace(
        $ForgotText,
        "(final\s+String\s+initialEmail\s*;)",
        "`$1`r`n  final bool admin;",
        1
    )
}

$ForgotText = $ForgotText.Replace(
    "bool get adminMode => isAdmin || role == 'admin';",
    "bool get adminMode => admin || isAdmin || role == 'admin';"
)

Save-Text $ForgotPath $ForgotText

$TravelerPagesText = Get-Content $TravelerPagesPath -Raw
if ($TravelerPagesText -notmatch "import\s+'dart:math';") {
    $TravelerPagesText = "import 'dart:math';`r`n" + $TravelerPagesText
}
# Remove a stale alias import created by an earlier patch.
$TravelerPagesText = $TravelerPagesText.Replace(
    "import 'dart:math' as math;`r`n",
    ""
)
Save-Text $TravelerPagesPath $TravelerPagesText

$ReviewText = Get-Content $ReviewModelPath -Raw
$ReviewText = $ReviewText.Replace("math.log(", "log(")
$ReviewText = $ReviewText.Replace("math.sqrt(", "sqrt(")
$ReviewText = $ReviewText.Replace("math.exp(", "exp(")
Save-Text $ReviewModelPath $ReviewText

# ---------------------------------------------------------------------------
# 2. Separate traveler and vendor Firestore profiles in the source code.
#
# users/{uid}   = traveler/admin profiles
# vendors/{uid} = vendor profiles
# ---------------------------------------------------------------------------
$ServicesPath = Join-Path $ProjectRoot "lib\core\services.dart"
$LoginPath = Join-Path $ProjectRoot "lib\auth\screens\login_page.dart"
$PlannerPath = Join-Path $ProjectRoot "lib\traveler\daily_planner\daily_planner_page.dart"

Backup-File $ServicesPath
Backup-File $LoginPath
Backup-File $PlannerPath

$ServicesText = Get-Content $ServicesPath -Raw

if ($ServicesText -notmatch "vendorRef\s*\(") {
    $ServicesText = [regex]::Replace(
        $ServicesText,
        "(static\s+DocumentReference<Map<String,\s*dynamic>>\s+userRef\(String\s+uid\)\s*=>\s*db\.collection\('users'\)\.doc\(uid\);)",
        "`$1`r`n`r`n  static DocumentReference<Map<String, dynamic>> vendorRef(String uid) =>`r`n      db.collection('vendors').doc(uid);",
        1
    )
}

if ($ServicesText -notmatch "profileForRole\s*\(") {
    $ProfileMethods = @'

  static Future<Map<String, dynamic>?> profileForRole(
    String uid,
    String role,
  ) async {
    if (role == 'vendor') {
      return (await vendorRef(uid).get()).data();
    }
    return (await userRef(uid).get()).data();
  }

  static Future<DocumentReference<Map<String, dynamic>>> accountRef(
    String uid,
  ) async {
    final vendor = await vendorRef(uid).get();
    if (vendor.exists) return vendorRef(uid);
    return userRef(uid);
  }
'@

    $ServicesText = [regex]::Replace(
        $ServicesText,
        "(static\s+DocumentReference<Map<String,\s*dynamic>>\s+vendorRef\(String\s+uid\)\s*=>\s*db\.collection\('vendors'\)\.doc\(uid\);)",
        "`$1$ProfileMethods",
        1
    )
}

# Replace currentProfile so the signed-in account can be traveler/admin or vendor.
$CurrentProfilePattern = "(?s)static\s+Future<Map<String,\s*dynamic>\?>\s+currentProfile\(\)\s+async\s*\{.*?^\s*\}"
$CurrentProfileReplacement = @'
static Future<Map<String, dynamic>?> currentProfile() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return null;

    final userProfile = (await userRef(uid).get()).data();
    if (userProfile != null) return userProfile;

    return (await vendorRef(uid).get()).data();
  }
'@
$ServicesText = [regex]::Replace(
    $ServicesText,
    $CurrentProfilePattern,
    $CurrentProfileReplacement,
    [System.Text.RegularExpressions.RegexOptions]::Multiline
)

# Vendor registration must write to vendors/{uid}, never users/{uid}.
$RegisterVendorStart = $ServicesText.IndexOf(
    "static Future<void> registerVendor"
)
if ($RegisterVendorStart -ge 0) {
    $RegisterVendorEnd = $ServicesText.IndexOf(
        "static List<String> _vendorPlannerCategories",
        $RegisterVendorStart
    )

    if ($RegisterVendorEnd -gt $RegisterVendorStart) {
        $Before = $ServicesText.Substring(0, $RegisterVendorStart)
        $VendorBlock = $ServicesText.Substring(
            $RegisterVendorStart,
            $RegisterVendorEnd - $RegisterVendorStart
        )
        $After = $ServicesText.Substring($RegisterVendorEnd)

        $VendorBlock = $VendorBlock.Replace(
            "await userRef(result.user!.uid).set({",
            "await vendorRef(result.user!.uid).set({"
        )

        $ServicesText = $Before + $VendorBlock + $After
    }
}

# Deactivation should update the correct collection.
$ServicesText = $ServicesText.Replace(
    "await userRef(user.uid).update({",
    "final profileRef = await accountRef(user.uid);`r`n`r`n    await profileRef.update({"
)

Save-Text $ServicesPath $ServicesText

# Login must look up the chosen role in the correct collection.
$LoginText = Get-Content $LoginPath -Raw
$LoginText = [regex]::Replace(
    $LoginText,
    "final\s+profile\s*=\s*\(await\s+AppServices\.userRef\(credential\.user!\.uid\)\.get\(\)\)\.data\(\);",
    "final profile = await AppServices.profileForRole(`r`n        credential.user!.uid,`r`n        widget.role,`r`n      );"
)
Save-Text $LoginPath $LoginText

# Daily Planner must load verified vendors from the vendors collection.
$PlannerText = Get-Content $PlannerPath -Raw
$PlannerText = $PlannerText.Replace(
    ".collection('users')`r`n        .where('role', isEqualTo: 'vendor')`r`n        .get();",
    ".collection('vendors')`r`n        .get();"
)
$PlannerText = $PlannerText.Replace(
    ".collection('users')`n        .where('role', isEqualTo: 'vendor')`n        .get();",
    ".collection('vendors')`n        .get();"
)
Save-Text $PlannerPath $PlannerText

# Vendor pages should always update/read vendors/{uid}.
$VendorRoot = Join-Path $ProjectRoot "lib\vendor"
if (Test-Path $VendorRoot) {
    Get-ChildItem $VendorRoot -Recurse -Filter *.dart | ForEach-Object {
        Backup-File $_.FullName
        $VendorText = Get-Content $_.FullName -Raw
        $VendorText = $VendorText.Replace(
            "AppServices.userRef(",
            "AppServices.vendorRef("
        )
        Save-Text $_.FullName $VendorText
    }
}

Write-Host "Source-code repair completed." -ForegroundColor Green
Write-Host ""
Write-Host "Correct Firestore profile structure:"
Write-Host "  users/{uid}   -> traveler or admin"
Write-Host "  vendors/{uid} -> vendor"
Write-Host ""
Write-Host "Next commands:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter analyze"
Write-Host "  flutter run"
