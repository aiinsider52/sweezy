# 🚀 Sweezy - Setup Instructions

## ⚠️ Important: Add JSON Files to Xcode

The JSON data files need to be manually added to the Xcode project target. Follow these steps:

### Step 1: Open Xcode
```bash
open sweezy.xcodeproj
```

### Step 2: Add JSON Files to Target

1. In Xcode, select the **sweezy** project in the navigator (left sidebar)
2. Select the **sweezy** target
3. Go to the **Build Phases** tab
4. Expand **Copy Bundle Resources**
5. Click the **+** button
6. Click **Add Other...** → **Add Files...**
7. Navigate to: `sweezy/Resources/AppContent/seeds/`
8. Select **ALL** `.json` files:
   - ✅ `guides.json`
   - ✅ `guides_extra.json`
   - ✅ `checklists.json`
   - ✅ `checklists_extra.json`
   - ✅ `places.json`
   - ✅ `places_extra.json`
   - ✅ `templates.json`
   - ✅ `templates_extra.json`
   - ✅ `news.json`
   - ✅ `news_extra.json`
   - ✅ `benefit_rules.json`
9. Make sure **"Copy items if needed"** is **UNCHECKED**
10. Make sure **"Add to targets: sweezy"** is **CHECKED**
11. Click **Add**

### Step 3: Clean and Rebuild

1. Press **Cmd+Shift+K** (Product → Clean Build Folder)
2. Press **Cmd+B** (Product → Build)
3. Run the app **Cmd+R**

---

## 📊 What's Included

### 📍 **29 Places** across Switzerland
- St. Gallen (SG): 13 locations
- Zürich (ZH): 8 locations
- Thurgau (TG): 1 location
- Bern (BE): 3 locations
- Geneva (GE): 3 locations
- Basel (BS): 1 location

### 📋 **15+ Checklists**
All 10 categories filled:
- Arrival, Housing, Insurance, Work
- Education, Family, Healthcare
- Legal, Finance, Integration

### 📚 **42 Guides**
In Ukrainian, English, and German

### 📄 **8 Document Templates**
- Municipality Registration
- Health Insurance Application
- Rental Application
- Doctor Appointment
- Job Application
- Bank Account Request
- School Enrollment
- Sozialhilfe Request

### 📰 **10 News Items**
Current updates in 3 languages

---

## 🐛 Troubleshooting

### Problem: "No results found" or empty screens

**Solution:** JSON files are not in the app bundle.
- Follow Step 2 above to add all JSON files to the target
- Make sure they appear in **Build Phases → Copy Bundle Resources**

### Problem: Guides show "0 articles available"

**Solution:** 
1. Check that `guides.json` and `guides_extra.json` are in Copy Bundle Resources
2. Clean build folder (Cmd+Shift+K)
3. Rebuild (Cmd+B)

### Problem: Map shows no locations

**Solution:**
1. Check that `places.json` and `places_extra.json` are in Copy Bundle Resources
2. Make sure location permissions are granted in iOS Settings

### Problem: Templates not showing

**Solution:**
1. Check that `templates.json` and `templates_extra.json` are in Copy Bundle Resources
2. Rebuild the app

---

## ✅ Verification

After setup, you should see:
- **Home screen**: Quick Actions cards working
- **Guides**: 42 articles across categories
- **Checklists**: 15+ checklists with progress tracking
- **Map**: 29 locations with pins
- **Templates**: 8 document templates
- **News**: 10 news items

---

## 📱 Features

- ✨ **Offline-first**: All content works without internet
- 🎨 **Glassmorphism design**: Modern, beautiful UI
- 🌍 **Multilingual**: Ukrainian, English, German, Russian
- 📍 **Interactive map**: Find help near you
- ✅ **Progress tracking**: Track your integration journey
- 📄 **Document templates**: Generate official letters
- 🔔 **News updates**: Stay informed

---

## 🆘 Need Help?

If data still doesn't load after following these steps:

1. Check Xcode console for errors (Cmd+Shift+Y)
2. Look for messages like: "⚠️ Could not find guides.json in bundle"
3. Verify files exist: `ls sweezy/Resources/AppContent/seeds/*.json`
4. Make sure you selected the **sweezy** target (not sweezyTests)

---

**Made with 💙💛 for Ukrainian refugees in Switzerland**

