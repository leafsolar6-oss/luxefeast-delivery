# Nature Fete — Firebase Push Notification Setup

The code is done and deployed. Pushes flow automatically once these two halves
are connected: **(A)** the apps get real Firebase config, **(B)** the backend
gets your service-account key. Until then everything builds and works — push
just stays quietly off.

---

## A. Create the Firebase project (free) — ~10 minutes

1. Go to **console.firebase.google.com** → **Add project** → name it
   `Nature Fete` → continue (Google Analytics optional — skip is fine).

2. From **Project overview**, click the **Android icon** and register the
   first app using this **exact** package name:

   | App | Package name (copy exactly) |
   |---|---|
   | Customer | `com.luxefeast.luxefeast_customer` |
   | Shop | `com.luxefeast.luxefeast_shop` |
   | Rider | `com.luxefeast.luxefeast_rider` |

   (Register & download `google-services.json` — repeat 3×, once per app.
   Nicknames are up to you; SHA-1 not needed for notifications.)

3. Replace the **placeholder** files in the repo with the real downloads
   (same paths, same filenames):
   ```
   customer_app/android/app/google-services.json
   shop_app/android/app/google-services.json
   rider_app/android/app/google-services.json
   ```
   Then commit & push (backend doesn't need this — Render only hosts the API).

## B. Give the backend permission to send — ~2 minutes

1. Firebase console → ⚙️ **Project settings** → **Service accounts** tab →
   **Generate new private key** → a JSON file downloads.

2. Open the JSON, copy **everything**.

3. Render dashboard → **luxefeast-api** → **Environment** → add:

   **Key:** `FIREBASE_SERVICE_ACCOUNT`
   **Value:** *(paste the whole JSON)*

4. Save → Render redeploys → logs should show
   `Push: Firebase Admin ready`.

## C. Build the new APKs

```bash
cd customer_app && flutter pub get && flutter build apk --release \
  --dart-define=API_BASE_URL=https://luxefeast-api.onrender.com
# repeat for shop_app and rider_app
```

First login on each phone asks for notification permission — accept it.

## How it behaves
- **App open:** animated in-app pop-ups (no duplicate notifications).
- **App closed/locked:** system notification with sound on the "Orders"
  channel — shop gets new orders, customers get every status change,
  riders get delivery offers.
- **Tap a notification:** opens the app (customer lands on live tracking).
- **Logout:** device stops receiving pushes automatically.
- Invalid/expired device tokens are pruned by the server automatically.
