# Guests Page Implementation

## Status: Implementation In Progress

## All Designs Analyzed (23/23)
- [x] 515-62641 - Guest list with tabs
- [x] 515-65207 - Guest details (Pending)
- [x] 515-65121 - Guest details (Approved)
- [x] 515-64797 - Empty state
- [x] 515-65302 - Remove guest alert
- [x] 515-64492 - Guest details (viewer)
- [x] 515-64408 - Multi-select + delete bar
- [x] 515-64683 - Import contacts modal
- [x] 515-63720 - Swipe actions
- [x] 515-62925 - Context menu
- [x] 515-63913 - Share sheet
- [x] 515-63569 - Add guest form
- [x] 515-64106 - Guest details alt
- [x] 1287-20817 - Toast/snackbar
- [x] 515-63235 - Edit guest inline
- [x] 515-64861 - List with badges
- [x] 515-64296 - Invite swipe
- [x] 515-64631 - Details expanded
- [x] 515-63396 - Delete All alert
- [x] 515-63074 - Multi-select with counter
- [x] 515-65047 - Details (Confirmed + Remove)
- [x] 515-64966 - Details (Share + Mail buttons)
- [x] 515-62783 - Select mode (radio buttons)

## Screen Types Summary

### 1. GuestsListView (Main Screen)
- Header: "Guests" title (34pt SF Pro Rounded Semibold)
- Segment tabs: All (with count badge) | Confirmed | Pending | Declined | Plus Ones
- Import From Contacts button (gray, with + icon)
- Guest list in white cards with dividers
- FAB: Purple gradient add button (bottom right)
- Nav: Back arrow (left), ellipsis menu (right)

### 2. Guest Details Sheet (Modal)
- Title: "Guest Details" (28pt)
- Sections: NAME, EMAIL, INFO (status + invite link)
- Two button variants:
  - Host view: "Share Link" + "Send via Mail" (purple outline)
  - Or: "Remove Guest" (red outline)
- Back/Done nav buttons

### 3. Multi-Select Mode
- Title changes to "X Selected" or "Select Guests"
- Radio buttons appear on each row
- Selected rows get highlight background
- Bottom bar: "Delete" button (red text)
- Nav: "Done" button (purple, right side)

### 4. Context Menu
- "Select Guests" option
- "Delete all" option (red, with bin icon)
- Triggers confirmation alert

### 5. Alerts
- Delete single: "Delete Guest?" / Cancel + Delete
- Delete multiple: "Delete X Guests?"
- Delete all: "Delete All Guests?"

### 6. Empty State
- Illustration graphic
- "No guests yet" text

## Color Tokens (from designs)
- Primary: #8251EB (purple)
- Background: #F2F2F7
- Card: #FFFFFF
- Text Primary: #0D1017
- Text Secondary: #9E9EAA
- Divider: rgba(156,156,166,0.2)
- Warning/Delete: #DB4F47
- Badge BG: #8251EB, text #F2F2F7

## Implementation Plan

### Phase 1: Core Files
1. [x] `Guest.swift` - Domain entity (already existed with RSVPStatus, GuestRole, plusOnes)
2. [x] `GuestRepository.swift` - Protocol + implementation (already existed)
3. [x] `GuestsViewModel.swift` - State management (updated with deleteAllGuests, plusOnes filter)

### Phase 2: Main Views
4. [x] `GuestsListView.swift` - Main container (updated with scroll tracking, FAB, context menu)
5. [x] `GuestTabBar` - Tab bar component (updated to underline indicator style)
6. [x] `GuestRow.swift` - List item with swipe (existing, needs verification)
7. [ ] `EmptyGuestsView.swift` - Empty state (may need Figma illustration update)

### Phase 3: Detail & Edit
8. [x] `GuestDetailsSheet` - Detail modal (created with NAME/EMAIL/INFO sections)
9. [x] `AddGuestSheet.swift` - Add/edit form (existing)

### Phase 4: Actions
10. [x] Multi-select mode logic in ViewModel
11. [x] Swipe actions (delete, invite)
12. [x] Context menu integration (Select Guests, Delete all)
13. [x] Share sheet integration (in GuestDetailsSheet)

### Phase 5: Polish
14. [ ] Import from contacts modal styling
15. [ ] Toast/snackbar notifications
16. [ ] Animations and transitions
