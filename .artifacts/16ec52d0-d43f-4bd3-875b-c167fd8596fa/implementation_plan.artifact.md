# Refactor Companion Page for Role-Based Functionality

This plan refactors the `CompanionPage` to clearly distinguish between **Member** and **Leader** roles within travel groups, providing specific quick-access actions for each.

## Proposed Changes

### [Companion Page Component](file:///C:/Users/ongwe/StudioProjects/myheritage-explorer/lib/traveler/companion/companion_page.dart)

#### [MODIFY] [companion_page.dart](file:///C:/Users/ongwe/StudioProjects/myheritage-explorer/lib/traveler/companion/companion_page.dart)

- **UI Restructuring**:
    - Move "Join" and "Create" actions to a more prominent "Group Management" section at the top of the page (or as primary actions) to ensure they are always accessible to users.
    - Categorize groups into "Groups you Lead" and "Groups you've Joined" (if both exist) or simply use a unified list with improved card designs.
- **Role-Specific Group Cards**:
    - **Member View**:
        - "Open Group Chat" button (Primary).
        - "EMERGENCY SOS" button (Danger themed, secondary).
        - Tapping the card body defaults to `GroupChatPage`.
    - **Leader View**:
        - "View Map" button (Primary).
        - "Manage Members" button (Secondary).
        - Tapping the card body defaults to `GroupDetailsPage` (full management).
- **Styling**:
    - Enhance `ExplorerCard` usage to make the role (LEADER/MEMBER) more visually distinct.

## Verification Plan

### Manual Verification
- Log in as a user who is a **Leader** of a group:
    - Verify that the card shows "Manage Members" and "View Map".
    - Verify tapping the card goes to `GroupDetailsPage`.
- Log in as a user who is a **Member** of a group:
    - Verify that the card shows "Open Group Chat" and "EMERGENCY SOS".
    - Verify tapping the card goes to `GroupChatPage`.
    - Verify that tapping "EMERGENCY SOS" opens the `SosPanicPage`.
- Verify that "Join" and "Create" buttons are easily accessible regardless of group status.
