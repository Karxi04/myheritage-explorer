import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// IMPORTANT:
// Flutter must be imported normally.
// DO NOT add "as something".
// DO NOT add "hide".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlng;
import 'package:mobile_scanner/mobile_scanner.dart' hide GeoPoint;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_pages.dart';
import '../core/helpers.dart';
import '../core/explorer_ui.dart';
import '../core/geoapify_config.dart';
import '../core/safety_config.dart';
import '../core/safety_error_message.dart';
import '../core/services.dart';
import '../core/pin_service.dart';
import '../core/ai_chat_service.dart';
import '../core/chatbot_module_service.dart';
import '../models/app_notification.dart';
import '../models/evidence_validation_result.dart';
import '../models/hazard_report.dart';
import '../models/hazard_vote.dart';
import '../models/itinerary_hazard_warning.dart';
import '../services/alert_cooldown_store.dart';
import '../services/background_location_permission_service.dart';
import '../services/confidence_analysis_service.dart';
import '../services/hazard_map_service.dart';
import '../services/hazard_report_service.dart';
import '../services/hazard_vote_service.dart';
import '../services/hazard_address_resolver.dart';
import '../services/place_geocoding_service.dart';
import '../services/itinerary_safety_service.dart';
import '../services/location_service.dart';
import '../services/mobile_notification_service.dart';
import '../services/notification_service.dart';
import '../services/safety_alert_priority_service.dart';
import '../widgets/duplicate_hazard_warning_sheet.dart';
import '../widgets/evidence_picker_card.dart';
import '../widgets/hazard_evidence_image.dart';
import '../widgets/safety_loading_state.dart';
import 'safety/navigation/safe_navigation_page.dart';

import 'daily_planner/models/itinerary_model.dart';
import 'daily_planner/models/travel_preferences_model.dart';
import 'daily_planner/services/daily_planner_date_validator.dart';
import 'daily_planner/services/malaysia_location_service.dart';
import 'daily_planner/services/place_repository.dart';
import 'daily_planner/services/cultural_task_service.dart';
import 'daily_planner/services/itinerary_recommendation_service.dart';
import 'daily_planner/services/review_service.dart';
import '../shared/shared_itinerary_page.dart';

part 'home/traveler_home_page.dart';
part 'daily_planner/malaysian_planner_data.dart';
part 'daily_planner/daily_planner_page.dart';
part 'daily_planner/review_ml_model.dart';
part 'daily_planner/review_flag_model.dart';
part 'daily_planner/place_detail_page.dart';
part 'daily_planner/my_itineraries_page.dart';
part 'daily_planner/itinerary_detail_page.dart';
part 'daily_planner/itinerary_share_helper.dart';
part 'daily_planner/itinerary_image_resolver.dart';
part 'daily_planner/itinerary_schedule_planner.dart';
part 'daily_planner/itinerary_edit_page.dart';

part 'cultural/cultural_tasks_page.dart';

part 'safety/safety_page.dart';
part 'safety/my_hazard_reports_page.dart';
part 'safety/create_hazard_page.dart';
part 'safety/hazard_detail_page.dart';
part 'safety/hazard_proximity_monitor.dart';
part 'safety/safety_priority_sheet.dart';
part 'safety/danger_zone_map_page.dart';
part 'safety/safety_alert_page.dart';

part 'companion/companion_page.dart';
part 'companion/companion_membership_api.dart';
part 'companion/create_group_page.dart';
part 'companion/join_group_page.dart';
part 'companion/group_details_page.dart';
part 'companion/manage_members_page.dart';
part 'companion/group_chat_page.dart';
part 'companion/group_map_page.dart';
part 'companion/companion_location_page.dart';
part 'companion/sos_panic_page.dart';
part 'companion/sos_alerts_review_page.dart';
part 'companion/route_guidance_page.dart';
part 'companion/private_chats_page.dart';
part 'companion/private_chat_page.dart';

part 'rewards/rewards_page.dart';
part 'rewards/voucher_detail_page.dart';
part 'rewards/nearby_rewards_page.dart';
part 'rewards/voucher_wallet_page.dart';
part 'rewards/reward_notification_settings_page.dart';

part 'weather/weather_reminder_page.dart';
part 'chatbot/chatbot_page.dart';
part 'notifications/notifications_page.dart';
part 'profile/traveler_profile_page.dart';
part 'profile/user_search_page.dart';
part 'profile/vendor_search_page.dart';
