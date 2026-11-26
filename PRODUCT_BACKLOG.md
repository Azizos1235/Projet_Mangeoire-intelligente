# Mangeoire Intelligente — Product Backlog

## Vision produit

La Mangeoire Intelligente aide les administrateurs et les éleveurs à suivre les animaux, leurs données d’alimentation et leur appétit, et à organiser les interventions d’élevage. Le produit comprend deux applications, une mangeoire connectée et des services de classification. Le stade déclaré est un prototype avancé / MVP ; le nombre d’exploitations utilisatrices et les objectifs commerciaux sont unknown.

## Rôles utilisateurs

| Rôle | Ce que le produit permet aujourd’hui, d’après les écrans et parcours présents |
|---|---|
| Administrateur | Gérer des profils de vaches et d’éleveurs, créer des invitations et QR, consulter les données et l’appétit du troupeau, traiter les alertes, attribuer des tâches et suivre son abonnement. Le superutilisateur est un administrateur ; ses fonctions de gestion d’autres administrateurs sont présentes côté services, mais leur disponibilité dans l’application est unknown. |
| Éleveur | S’inscrire par invitation, se connecter par QR, consulter et modifier les profils de ses vaches, scanner des tags NFC, suivre des mesures et l’appétit, et consulter et terminer ses tâches. |

## Vue des epics

| Epic | Objectif utilisateur |
|---|---|
| Accéder à mon compte | Se connecter, s’inscrire, changer de mot de passe et choisir sa langue. |
| Gérer mon élevage et mes accès | Inviter des éleveurs, administrer leurs accès et traiter les demandes liées aux abonnements. |
| Gérer et retrouver mes vaches | Consulter et mettre à jour les profils, les rechercher et les identifier par NFC. |
| Comprendre l’alimentation et l’appétit | Consulter les mesures, l’historique, les tendances et les estimations disponibles. |
| Traiter les alertes et les tâches | Suivre les événements du troupeau, attribuer et terminer les tâches. |
| Utiliser la mangeoire | Identifier les vaches et suivre la distribution d’aliment. |

## Stories priorisées

### Epic — Accéder à mon compte

#### US1 — Connexion administrateur
- **User role :** Administrator
- **Story statement :** As an administrator, I want to sign in with my email and password, so that I can access my farm workspace.
- **Acceptance criteria :**
  - Given an active administrator account, when I enter the correct email and password, then I arrive at the administrator home screen.
  - Given an incorrect email or password, when I try to sign in, then I see an access error and remain signed out.
  - Given an expired subscription, when I sign in, then I see the subscription-expired screen.
- **Priority :** Must · **Estimate :** 3 points · **Status :** Existing

#### US2 — Inscription éleveur par invitation
- **User role :** Farmer
- **Story statement :** As a farmer, I want to create my account with an invitation, so that I can join my administrator’s farm.
- **Acceptance criteria :**
  - Given a valid invitation, when I enter my name and submit registration, then my account is created and I am signed in.
  - Given an expired or used invitation, when I submit it, then I am told that it is no longer valid.
  - Given an invalid registration form, when I submit it, then I see what needs correcting and no account is created.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US3 — Scanner un QR d’invitation ou de connexion
- **User role :** Farmer
- **Story statement :** As a farmer, I want to scan an invitation or login QR code with my phone, so that I can register or access my account without typing its code.
- **Acceptance criteria :**
  - Given an invitation QR code, when I scan it, then I am taken to the invitation confirmation and registration flow.
  - Given a login QR code, when I scan it and confirm my name, then I am signed in to the matching account.
  - Given an unreadable, invalid, expired, or cancelled scan, when the scan ends, then I see an appropriate message and can try again.
- **Priority :** Must · **Estimate :** 8 points · **Status :** Existing

#### US4 — Connexion biométrique
- **User role :** Farmer
- **Story statement :** As a farmer, I want to sign in with biometrics on a compatible phone, so that I can return to my account more easily.
- **Acceptance criteria :**
  - Given a compatible phone and an existing account, when I choose biometric sign-in, then I can authenticate using the phone’s supported biometric method.
  - Given an unavailable or unsuccessful biometric check, when I try to sign in, then I can use the existing QR sign-in flow instead.
  - Given I have not enabled biometric sign-in, when I open the sign-in screen, then the app explains how to continue without it.
- **Priority :** Could · **Estimate :** 8 points · **Status :** Partial

#### US5 — Changer le mot de passe administrateur
- **User role :** Administrator
- **Story statement :** As an administrator, I want to change my password after confirming my current password, so that I can keep control of my account.
- **Acceptance criteria :**
  - Given my current password, when I enter it and a valid new password, then I receive confirmation that the password changed.
  - Given an incorrect current password, when I submit the change, then my password remains unchanged and I see an error.
  - Given a new password shorter than the accepted minimum, when I submit it, then I am asked to choose a valid password.
- **Priority :** Must · **Estimate :** 3 points · **Status :** Existing

#### US6 — Retrouver ou fermer ma session
- **User role :** Signed-in user
- **Story statement :** As a signed-in user, I want my session to be restored when I reopen the app and to be able to sign out, so that I can control access to my account.
- **Acceptance criteria :**
  - Given a valid saved session, when I reopen the app, then I return to the appropriate signed-in screen.
  - Given an expired session, when I reopen the app, then I am asked to sign in again.
  - Given I choose to sign out, when the action completes, then I return to the sign-in screen.
- **Priority :** Must · **Estimate :** 3 points · **Status :** Existing

#### US7 — Choisir la langue de l’application
- **User role :** Farmer
- **Story statement :** As a farmer, I want to choose French or Arabic, so that I can use the app in a language I understand.
- **Acceptance criteria :**
  - Given either available language, when I select it, then the app displays its supported text in that language.
  - Given Arabic is selected, when I browse the app, then the layout follows right-to-left reading direction.
  - Given I move between screens, when the language is selected, then the choice remains consistent during the session.
- **Priority :** Should · **Estimate :** 3 points · **Status :** Existing

### Epic — Gérer mon élevage et mes accès

#### US8 — Créer et suivre des invitations
- **User role :** Administrator
- **Story statement :** As an administrator, I want to create, view, and cancel farmer invitations, so that I can control who joins my farm.
- **Acceptance criteria :**
  - Given my administrator account, when I create an invitation, then I can share its QR code before it expires.
  - Given my invitation list, when I view it, then I can distinguish active, used, and expired invitations.
  - Given an active unused invitation, when I cancel it, then it can no longer be used to register.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US9 — Gérer les éleveurs de mon exploitation
- **User role :** Administrator
- **Story statement :** As an administrator, I want to view my farmers, issue them a login QR code, and remove their access, so that I can manage my team.
- **Acceptance criteria :**
  - Given farmers associated with my farm, when I open the farmer list, then I see their names.
  - Given one of my farmers, when I request a login QR code, then I can share a time-limited code for that farmer.
  - Given a farmer I manage, when I confirm removal, then that account can no longer access my farm.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US10 — Demander un compte administrateur
- **User role :** Administrator
- **Story statement :** As an administrator, I want to submit my contact details to request an administrator account, so that my access request can be reviewed.
- **Acceptance criteria :**
  - Given the access-request form, when I submit valid contact details, then I see confirmation that my request was received.
  - Given an invalid email or missing required detail, when I submit the form, then I see what must be corrected.
  - Given an existing pending request for the same email, when I submit another one, then I am told that a request is already pending.
- **Priority :** Should · **Estimate :** 3 points · **Status :** Existing

#### US11 — Traiter les demandes d’accès et de renouvellement
- **User role :** Administrator
- **Story statement :** As an administrator responsible for account requests, I want to review, approve, or reject signup and renewal requests, so that access decisions are clear and timely.
- **Acceptance criteria :**
  - Given pending requests, when I open the request list, then I can distinguish signup requests from renewal requests and see their status.
  - Given a pending signup request, when I approve it, then the applicant receives an administrator account and the required first-login information.
  - Given a pending request, when I reject it, then its status changes to rejected and the decision is recorded.
- **Priority :** Should · **Estimate :** 8 points · **Status :** Partial

#### US12 — Gérer les comptes administrateurs
- **User role :** Administrator
- **Story statement :** As an administrator responsible for accounts, I want to view administrator accounts, renew their access, reset their password, or remove an account, so that I can manage the service’s administrators.
- **Acceptance criteria :**
  - Given the administrator account list, when I open it, then I can see each account’s status and subscription information.
  - Given an administrator account, when I renew its subscription or reset its password, then I see confirmation of the resulting access state.
  - Given an administrator account selected for removal, when I confirm the action, then its access is removed and the outcome is shown.
- **Priority :** Should · **Estimate :** 8 points · **Status :** Partial

#### US13 — Suivre mon abonnement
- **User role :** Administrator
- **Story statement :** As an administrator, I want to view my subscription status and request a renewal, so that I can keep access to my farm.
- **Acceptance criteria :**
  - Given an active subscription, when I open subscription details, then I see its expiry date and remaining time.
  - Given an expired subscription, when I open the app, then I see the expired state and a way to request renewal.
  - Given a renewal request is already pending, when I try to submit another, then I am informed that a request is already in progress.
- **Priority :** Must · **Estimate :** 3 points · **Status :** Existing

### Epic — Gérer et retrouver mes vaches

#### US14 — Gérer les profils de vaches comme administrateur
- **User role :** Administrator
- **Story statement :** As an administrator, I want to create, view, edit, and remove cow profiles, so that my herd information stays current.
- **Acceptance criteria :**
  - Given valid cow details, when I save a new profile, then it appears in my cow list.
  - Given an existing profile, when I update its details, then the cow view shows the saved information.
  - Given an existing profile, when I confirm removal, then the cow is removed from my list.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US15 — Gérer les profils de mes vaches comme éleveur
- **User role :** Farmer
- **Story statement :** As a farmer, I want to view, add, and edit my cow profiles, so that I can keep my herd information up to date.
- **Acceptance criteria :**
  - Given my farm’s cows, when I open the cow list, then I see the profiles available to my account.
  - Given a new cow and its required NFC tag, when I save its profile, then it appears in my list.
  - Given one of my cow profiles, when I save valid edits, then the updated details appear in its profile.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US16 — Identifier une vache par NFC
- **User role :** Signed-in user
- **Story statement :** As a signed-in user, I want to scan a cow’s NFC tag and open its profile, so that I can identify the animal quickly.
- **Acceptance criteria :**
  - Given a registered tag belonging to my farm, when I scan it, then I can open the matching cow profile.
  - Given an unknown tag, when I scan it, then I am told that no matching profile was found.
  - Given a tag registered to another farm, when I scan it, then no other farm’s profile details are shown.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US17 — Rechercher et filtrer les vaches
- **User role :** Administrator
- **Story statement :** As an administrator, I want to search my cow list by identifier or breed and filter by appetite class, so that I can find animals needing attention.
- **Acceptance criteria :**
  - Given my cow list, when I enter an identifier or breed, then matching cows are shown.
  - Given appetite classifications are available, when I select an appetite filter, then only cows in that class are shown.
  - Given no cow matches my search and filter, when the results update, then I see an empty-state message.
- **Priority :** Should · **Estimate :** 3 points · **Status :** Existing

### Epic — Comprendre l’alimentation et l’appétit

#### US18 — Consulter les dernières mesures
- **User role :** Signed-in user
- **Story statement :** As a signed-in user, I want to see a cow’s latest feeding and activity measurements, so that I can understand its recent behavior.
- **Acceptance criteria :**
  - Given a cow with recent measurements, when I open its detail, then I see the latest available values and their time.
  - Given no measurement is available, when I open the detail, then I see that the data is unavailable rather than an invented value.
  - Given a measurement cannot be loaded, when I retry, then the app either displays the result or explains the problem.
- **Priority :** Must · **Estimate :** 3 points · **Status :** Existing

#### US19 — Consulter l’historique journalier
- **User role :** Signed-in user
- **Story statement :** As a signed-in user, I want to view a cow’s daily measurements and select a day, so that I can compare its feeding history.
- **Acceptance criteria :**
  - Given daily records for a cow, when I open its history, then I can view the available days and measurements.
  - Given a date with a record, when I select it, then I see the measurements for that date.
  - Given a date without a record, when I select it, then I see that no data is available for that day.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US20 — Suivre les mesures en direct
- **User role :** Signed-in user
- **Story statement :** As a signed-in user, I want to see new cow measurements appear while I view its detail, so that I can follow recent activity.
- **Acceptance criteria :**
  - Given I am viewing a cow with live updates available, when a new reading arrives, then the displayed reading is updated.
  - Given live updates are unavailable, when I open the detail, then I can still see the latest saved reading when one exists.
  - Given no live or saved reading is available, when I view the detail, then the app clearly indicates that state.
- **Priority :** Should · **Estimate :** 5 points · **Status :** Existing

#### US21 — Consulter les distributions d’aliment
- **User role :** Administrator
- **Story statement :** As an administrator, I want to view a cow’s recent feed-dispatch records, so that I can check what the feeder has dispensed.
- **Acceptance criteria :**
  - Given dispatch records exist, when I open the cow detail, then I can see the recent records and their available values.
  - Given no dispatch record exists, when I open the dispatch section, then I see an empty state.
  - Given records cannot be loaded, when I retry, then I see either the loaded records or an explanatory error.
- **Priority :** Should · **Estimate :** 3 points · **Status :** Existing

#### US22 — Suivre l’appétit du troupeau
- **User role :** Administrator
- **Story statement :** As an administrator, I want to see appetite classes and unread-alert counts across my herd, so that I can identify cows needing attention.
- **Acceptance criteria :**
  - Given appetite data is available, when I open the dashboard, then I see cows grouped or summarized by appetite class.
  - Given unread alerts exist, when I view the dashboard, then I see their count and can open the alert list.
  - Given appetite data is missing, when I view the dashboard, then missing data is distinguished from a normal appetite classification.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US23 — Comprendre l’appétit d’une vache
- **User role :** Farmer
- **Story statement :** As a farmer, I want to see my cow’s appetite class, recent trend, and available explanation, so that I can follow changes in its feeding behavior.
- **Acceptance criteria :**
  - Given appetite results exist, when I open a cow detail, then I see its current class and recent trend.
  - Given confidence or class percentages are available, when I view the result, then I can see those values with clear labels.
  - Given appetite data is unavailable, when I open the detail, then the app states that it cannot provide a result.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US24 — Obtenir une recommandation d’alimentation
- **User role :** Farmer
- **Story statement :** As a farmer, I want to receive a useful feeding recommendation for a cow, so that I can make an informed feeding decision.
- **Acceptance criteria :**
  - Given sufficient cow and feeding data, when I open the feeding section, then I see a recommendation and the information it is based on.
  - Given data is insufficient, when I open the feeding section, then I see which information is unavailable instead of a fabricated recommendation.
  - Given a recommendation cannot be produced, when I open the feeding section, then I see a clear unavailable state.
- **Priority :** Should · **Estimate :** 8 points · **Status :** Partial

#### US25 — Consulter une estimation d’ingestion
- **User role :** Farmer
- **Story statement :** As a farmer, I want to see an estimated daily feed intake for a cow, so that I can compare its estimated needs with its recorded feeding.
- **Acceptance criteria :**
  - Given a cow profile with the required details, when I request an estimate, then I see an estimated daily intake with its unit.
  - Given required profile details are missing, when I request an estimate, then I am told which details are needed.
  - Given no estimate is available, when I view the feeding section, then the app does not present an unverified value as fact.
- **Priority :** Could · **Estimate :** 8 points · **Status :** Partial

#### US26 — Régler la sensibilité des alertes d’appétit
- **User role :** Administrator
- **Story statement :** As an administrator, I want to choose how sensitive appetite alerts are for my farm, so that the alerts better match the herd I manage.
- **Acceptance criteria :**
  - Given appetite alert settings, when I choose a supported sensitivity, then the app shows the selected setting.
  - Given a new appetite result, when it is evaluated, then alert behavior follows the setting I selected.
  - Given I have not changed the setting, when an appetite result is evaluated, then the existing default behavior is preserved.
- **Priority :** Could · **Estimate :** 8 points · **Status :** New

### Epic — Traiter les alertes et les tâches

#### US27 — Consulter et traiter les alertes
- **User role :** Administrator
- **Story statement :** As an administrator, I want to view appetite and task-completion alerts, filter read and unread alerts, and open the related cow, so that I can follow up on important events.
- **Acceptance criteria :**
  - Given alerts exist, when I open the alert list, then I see their type, time, and related cow when available.
  - Given read and unread alerts, when I choose a status filter or mark an alert as read, then the displayed status updates.
  - Given an alert refers to a cow, when I open it, then I can navigate to that cow’s details.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US28 — Attribuer une tâche à un éleveur
- **User role :** Administrator
- **Story statement :** As an administrator, I want to assign a dated task to a farmer and optionally link it to a cow or appetite alert, so that the needed follow-up is clear.
- **Acceptance criteria :**
  - Given a farmer in my team, when I create a task with a title and type, then it appears in my task list.
  - Given a task linked to a cow or appetite alert, when I save it, then the related item is visible from the task.
  - Given tasks with different statuses or farmers, when I filter the list, then I see the matching tasks.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US29 — Consulter et terminer mes tâches
- **User role :** Farmer
- **Story statement :** As a farmer, I want to view my pending tasks and mark them complete with an optional note or weight, so that my administrator can follow the work done.
- **Acceptance criteria :**
  - Given pending tasks assigned to me, when I open the task list, then I can see their descriptions and due dates when available.
  - Given a task I have completed, when I submit it with an optional note or weight, then it is marked complete.
  - Given completion is recorded, when my administrator views the task, then its completion details are available.
- **Priority :** Must · **Estimate :** 5 points · **Status :** Existing

#### US30 — Recevoir des notifications d’alertes et de tâches
- **User role :** Signed-in user
- **Story statement :** As a signed-in user, I want to be notified about relevant alerts or tasks when I am not using the app, so that I can respond promptly.
- **Acceptance criteria :**
  - Given notifications are enabled and permission is granted, when a supported alert or task is found, then I receive a notification on a supported device.
  - Given I open a notification, when the app is available, then I am taken to the related alert, task, or list.
  - Given notifications are disabled or unavailable, when I view notification settings, then I can see the current state and how to change it.
- **Priority :** Should · **Estimate :** 8 points · **Status :** Partial

#### US31 — Consulter mes tâches terminées
- **User role :** Farmer
- **Story statement :** As a farmer, I want to review tasks I have completed, so that I can remember what work was done.
- **Acceptance criteria :**
  - Given I have completed tasks, when I open task history, then I can see their titles and completion dates.
  - Given a completed task has a note or recorded weight, when I open it, then I can review those details.
  - Given I have not completed any tasks, when I open task history, then I see an empty state.
- **Priority :** Could · **Estimate :** 5 points · **Status :** New

### Epic — Utiliser la mangeoire

#### US32 — Identifier une vache auprès de la mangeoire
- **User role :** Farmer
- **Story statement :** As a farmer, I want a cow’s RFID tag to identify the animal at the feeder and record its visit, so that feeding activity can be associated with the right cow.
- **Acceptance criteria :**
  - Given a recognized cow tag is held at the reader for the required time, when the visit is registered, then the visit is associated with that tag.
  - Given the tag is unknown or the visit is too short, when the tag is removed, then no valid feeding visit is shown for that attempt.
  - Given the feeder cannot contact the service, when a visit is attempted, then the user-facing result does not claim that a feeding request succeeded.
- **Priority :** Must · **Estimate :** 8 points · **Status :** Partial

#### US33 — Distribuer la quantité demandée
- **User role :** Farmer
- **Story statement :** As a farmer, I want the feeder to dispense the quantity returned for a recognized cow, so that feeding is adapted to the animal.
- **Acceptance criteria :**
  - Given a valid feeding response for a recognized cow, when the feeder processes it, then it dispenses the returned quantity.
  - Given no valid response is received, when the request times out, then the feeder follows its available fallback behavior and does not report a successful response.
  - Given a distribution is recorded, when I view the cow’s feeding details, then the available distribution record is shown.
- **Priority :** Should · **Estimate :** 8 points · **Status :** Partial

## Open questions

- The target users, number of farms, commercial goals, and release date are unknown.
- Superuser endpoints exist, but the availability of corresponding screens in the administrator app is unknown.
- The QR camera flow is present in the Android app despite the README saying it is not configured; support on other platforms is unknown.
- Biometric sign-in is explicitly unavailable in the current screen; supported devices and desired sign-in policy are unknown.
- The farmer app has local/background notification controls; expected delivery platforms and whether remote push is required are unknown.
- The regression model can estimate intake offline, but the intended production recommendation rules and acceptable validation criteria are unknown.
- Appetite sensitivity may be global or farm-specific; the desired behavior and defaults are unknown.
- ESP32 code implements RFID, date handling, CoAP/DTLS requests, and servo actions, but the hardware’s production behavior and supported installation conditions are unknown.
