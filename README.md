# StaffSync

## Smart Staff Management System

StaffSync is a cross-platform staff management and workforce automation system developed as a Final Year Project (FYP). The system provides a centralized platform for managing employees, attendance, shifts, payroll, leaves, tasks, notifications, reporting, and administrative operations.

The project aims to reduce manual workload and improve workforce efficiency through automation and real-time data management.

---

# Project Objectives

* Digitize employee management operations.
* Reduce paperwork and manual record keeping.
* Automate attendance, payroll, and task management.
* Provide centralized administration and reporting.
* Support multilingual communication and AI-assisted features.
* Improve monitoring and decision-making through analytics.

---

# Technology Stack

## Frontend

* Flutter (Dart)

## Backend

* ASP.NET Core Web API (C#)

## Database

* Firebase Firestore

## Authentication

* Firebase Authentication

## Additional Technologies

* REST APIs
* PDF Report Generation
* Notification Services
* Offline Data Synchronization

---

# System Modules

## Authentication Module

* Create Account
* Login Account
* Logout
* Password Reset

---

## Staff Management Module

* Add Staff
* View Staff
* Update Staff
* Delete Staff

---

## Attendance Management Module

* Mark Attendance
* View Attendance
* Update Attendance
* Generate Attendance Reports

---

## Shift Management Module

* Create Shift
* Assign Shift
* Update Shift
* Delete Shift

---

## Leave Management Module

* Apply Leave
* Approve or Reject Leave
* View Leave Status

---

## Task Management Module

* Assign Tasks
* Submit Task Proof
* Verify Tasks

---

## Payroll Management Module

* Salary Calculation
* Generate Payslips
* Payroll Reports

---

## Notification Module

* Send Notifications
* View Notifications

---

## Reporting Module

* Dashboard Analytics
* Generate Reports
* Export Reports

---

## Offline Synchronization

The system supports offline operations and synchronizes data automatically when internet connectivity becomes available.

---

# AI Features

### Absentee Prediction

Predicts possible employee absence trends using attendance records.

### AI-Based Message Translation

Converts notifications and messages into multiple languages.

### Multilingual Voice Announcements

Generates voice announcements for staff communication.

---

# System Workflow

```
Admin Login
     ↓
Dashboard
     ↓
Staff Management
     ↓
Attendance Tracking
     ↓
Shift Assignment
     ↓
Leave Management
     ↓
Task Management
     ↓
Payroll Generation
     ↓
Notifications
     ↓
Reports & Export
```

---

# User Roles

## Administrator

* Manage Employees
* Manage Attendance
* Manage Shifts
* Approve Leaves
* Assign Tasks
* Verify Tasks
* Generate Payroll
* Send Notifications
* Generate Reports
* View Dashboard Analytics

## Staff

* Login
* Mark Attendance
* Apply Leave
* View Assigned Tasks
* Submit Task Proof
* View Notifications
* View Payroll Information

---

# Admin Credentials

```
Email:
____________________

Password:
____________________
```

---

# Installation Guide

## Clone Repository

```bash
git clone <https://github.com/ahmad3545/Staff-Sync.git>
```

---

## Frontend Setup

```bash
flutter pub get
flutter run
```

---

## Backend Setup

```bash
cd backend/StaffSync.Api
dotnet restore
dotnet run
```

---

## Firebase Configuration

1. Create a Firebase Project.
2. Enable Authentication.
3. Enable Firestore Database.
4. Add Firebase configuration files.
5. Configure API keys.

---

# Folder Structure

```
lib/
backend/
controllers/
models/
services/
screens/
firebase/
reports/
```

---

# Future Enhancements

* AI Chat Assistant
* Face Recognition Attendance
* Geofencing Attendance
* Performance Analytics
* Employee Recommendation System
* Predictive Payroll Insights
* Voice Command Support
* Real-Time Chat System
* Mobile Push Notifications
* Cloud Deployment

---

# Academic Information

Final Year Project (Phase-II)

Department of Computer Science

University of Lahore

Convener:
Abdul Ghaffar

---

# Authors

Ahmad Raza
Ali Hassnan

University of Lahore

---

# License

This project is developed for educational and research purposes.
