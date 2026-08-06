import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../admin/admin_shell.dart';
import '../core/helpers.dart';
import '../core/explorer_ui.dart';
import '../core/services.dart';
import '../traveler/traveler_shell.dart';
import '../vendor/vendor_shell.dart';
import 'auth_pages.dart';


part 'gate/auth_gate_view.dart';
part 'gate/email_verification_page.dart';
part 'gate/vendor_pending_page.dart';
part 'gate/account_disabled_page.dart';
part 'gate/platform_restriction_page.dart';
part 'gate/missing_profile_page.dart';
