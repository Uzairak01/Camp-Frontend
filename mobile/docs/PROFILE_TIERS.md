# CAMP Rider Profile: Tiers & Trail Badges

This document details the progression tiers, earned badges, and mathematical formulas powering the rider profile dashboard in CAMP. All metrics are computed strictly from real ride debrief logs (`RideReportRepository` / `PostRideReportController`) without mock numbers or hardcoded placeholders.

---

## 1. Core Profile Stat Formulas

| Metric | Source Field | Computation Formula | Empty State Value |
| :--- | :--- | :--- | :--- |
| **Lifetime Distance** | `PostRideReport.distanceKm` | $\sum \text{distanceKm}$ across all reports | `0 km` |
| **Rides Completed** | `List<PostRideReport>` | Count of ride records ($N$) | `0 rides` |
| **Saddle Time** | `PostRideReport.durationHours` | $\sum \text{durationHours}$ across all reports | `-` |
| **Longest Single Ride** | `PostRideReport.distanceKm` | $\max(\text{distanceKm})$ across all reports | `-` |

When no ride records exist, the profile stat card displays:
- **Lifetime Distance**: `0 km`
- **Rides Completed**: `0 rides`
- **Saddle Time**: `-`
- **Longest Single Ride**: `-`
- **Status State**: `"No rides yet"`

---

## 2. Touring Tiers Progression

Tiers reward cumulative lifetime distance across all expeditions. Thresholds are defined in `lib/features/dashboard/domain/profile_tier_constants.dart`.

| Level | Tier Name | Lifetime Distance Threshold | Progress Range |
| :---: | :--- | :---: | :--- |
| **1** | Rookie | $0\text{ km}$ | $0\text{ km} \le \text{dist} < 500\text{ km}$ |
| **2** | Explorer | $500\text{ km}$ | $500\text{ km} \le \text{dist} < 2{,}000\text{ km}$ |
| **3** | Road Warrior | $2{,}000\text{ km}$ | $2{,}000\text{ km} \le \text{dist} < 5{,}000\text{ km}$ |
| **4** | Master Explorer | $5{,}000\text{ km}$ | $5{,}000\text{ km} \le \text{dist} < 10{,}000\text{ km}$ |
| **5** | Legend | $10{,}000\text{ km}$ | $\text{dist} \ge 10{,}000\text{ km}$ (Top Tier) |

### Progress Calculations:
- **Active Tier**: Highest level whose threshold is $\le \text{lifetimeDistanceKm}$.
- **Next Tier**: The immediate subsequent level ($N + 1$), or `null` if Level 5 Legend is reached.
- **Remaining Distance to Next Tier**:
  $$\Delta_{\text{next}} = \text{Threshold}_{\text{next}} - \text{lifetimeDistanceKm}$$
- **Progress Fraction within Current Tier Span**:
  $$\text{Progress} = \frac{\text{lifetimeDistanceKm} - \text{Threshold}_{\text{current}}}{\text{Threshold}_{\text{next}} - \text{Threshold}_{\text{current}}}$$
- **Top Tier State**: When $\text{lifetimeDistanceKm} \ge 10{,}000\text{ km}$, progress is $100\%$ ($1.0$), and the label displays:
  `"Top tier reached"`

---

## 3. Trail Badges & Unlock Criteria

Badges are dynamically unlocked based on validated milestones from the rider's saved ride history. Locked badges are greyed out with their unlock requirement clearly displayed; unlocked badges render in full tactical orange.

| Badge Name | Requirement | Computation Rule | Unlock Icon |
| :--- | :--- | :--- | :--- |
| **First Ride** | Complete 1 ride | `ridesCount >= 1` | `Icons.two_wheeler_rounded` |
| **100 km Club** | Reach 100 km lifetime | `lifetimeDistanceKm >= 100.0` | `Icons.speed_rounded` |
| **500 km Club** | Reach 500 km lifetime | `lifetimeDistanceKm >= 500.0` | `Icons.explore_rounded` |
| **1,000 km Club** | Reach 1,000 km lifetime | `lifetimeDistanceKm >= 1000.0` | `Icons.military_tech_rounded` |
| **Long Haul** | Complete a single ride $\ge 100\text{ km}$ | $\exists \, r \in \text{reports}: r.\text{distanceKm} \ge 100.0$ | `Icons.route_rounded` |
| **Ten Rides** | Complete 10 rides | `ridesCount >= 10` | `Icons.workspace_premium_rounded` |

---

## 4. Maintenance Health Status Determination

Motorcycle maintenance state on the profile and garage screens is derived strictly from `MaintenanceRepository`:
1. If zero maintenance items exist for the motorcycle:
   $$\text{Status} = \text{"No data yet"}$$
2. If any item has status `MaintenanceStatus.overdue`:
   $$\text{Status} = \text{"Overdue" (Worst State, Red)}$$
3. Else if any item has status `MaintenanceStatus.dueSoon`:
   $$\text{Status} = \text{"Due soon" (Warning State, Orange)}$$
4. Else if all items are `MaintenanceStatus.ok`:
   $$\text{Status} = \text{"OK" / "Good" (Healthy State, Green)}$$
