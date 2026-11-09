# CAMP Rider-Set Service Schedule Engine

## 1. Overview
CAMP features a 100% software-based, deterministic maintenance engine where riders configure their own service schedule per motorcycle. There are no silent defaults, no sensor dependencies, and no estimated costs. Every reminder is derived from rider-configured intervals, user-entered odometer readings, service milestone dates, and logged ride debriefs.

## 2. Core Principles
- **No Silent Defaults**: A new service item has no interval and no last-done values until entered by the rider. An unconfigured item has a status of `Not set up` and never produces an alert.
- **Rider-Entered Costs Only**: The engine never generates, suggests, or estimates financial costs. Costs are recorded exclusively when entered by the rider.
- **Pure Software Formula**: All remaining distances, time deltas, and projected dates use documented, deterministic arithmetic.

## 3. Supported Service Items
- **Oil + Small Service**: Engine oil change and general inspection.
- **Oil Filter**: Engine oil filter replacement.
- **Air Filter**: Air filter element cleaning/replacement.
- **Drive Chain**: Chain tension adjustment, cleaning, and lubrication.
- **Spark Plug**: Spark plug inspection or replacement.
- **Tuning**: Valve clearance check and engine tuning.
- **Brakes**: Brake pad and fluid inspection.
- **Tyres**: Tyre tread depth and pressure service.
- **Battery**: Terminal check and voltage inspection.
- **Carburetor**: Jetting inspection and slide cleaning (offered only for carbureted motorcycles).

## 4. Intervals and Harsh Conditions
Each enabled service item can specify:
- An interval in distance: `intervalKm` (nullable)
- An interval in time: `intervalMonths` (nullable)

### Harsh Conditions Adjustment
A per-bike switch allows riders to activate "Harsh conditions (dust, heat, off-road, heavy traffic)".
- When enabled, all distance intervals are shortened by exactly 20%:
  $$\text{effectiveIntervalKm} = \text{round}(\text{intervalKm} \times 0.80)$$
- When disabled:
  $$\text{effectiveIntervalKm} = \text{intervalKm}$$
- The UI transparently presents this adjustment, e.g.:
  `1,200 km → 960 km (harsh conditions)`

## 5. Due Status & Boundary Logic
Whichever interval limit comes first governs the due status:

$$\text{nextDueKm} = \text{lastDoneKm} + \text{effectiveIntervalKm}$$
$$\text{remainingKm} = \text{nextDueKm} - \text{currentOdometerKm}$$

$$\text{nextDueDate} = \text{lastDoneDate} + \text{intervalMonths}$$
$$\text{remainingDays} = \text{difference in days between nextDueDate and current date}$$

### Status Classification:
1. **Not Set Up**:
   - `intervalKm == null && intervalMonths == null`
   - Does not produce reminders or alerts.
2. **Add Last Done**:
   - Interval is configured, but `lastDoneKm == null && lastDoneDate == null`.
   - Prompted to enter the baseline service point; not counted as overdue.
3. **Overdue**:
   - `remainingKm <= 0`, OR
   - `nextDueDate` has passed (`remainingDays <= 0` or date is before now).
4. **Due Soon**:
   - Not overdue, AND
   - `remainingKm <= (effectiveIntervalKm * 0.10)` (within 10% of interval), OR
   - `remainingDays <= 14` (within 14 calendar days).
5. **OK**:
   - All configured criteria are within safe margins.

## 6. Real-Data Predicted Date
Predicted due dates project when a component will reach its distance threshold based on the rider's real driving habits:

$$\text{predictedDays} = \text{round}\left(\frac{\text{remainingKm}}{\text{averageKmPerDay}}\right)$$
$$\text{predictedDate} = \text{today} + \text{predictedDays}$$

### Strict Data Availability Rule:
- Calculated from logged ride debriefs (`PostRideReport`) and odometer history over the trailing 30 days.
- **Minimum Threshold**: Requires at least 7 days of historical logging and total logged distance $> 0\text{ km}$.
- If fewer than 7 days of data exist or no kilometers were logged, **no prediction is displayed**.
- No fallback estimates or assumed defaults are ever applied.

## 7. Marking Service Done
When a rider marks an item done:
1. Odometer is prefilled from the bike's current reading (rider can edit).
2. Service date defaults to today.
3. The item's `lastDoneKm` and `lastDoneDate` are updated.
4. A permanent service record is recorded.
5. An optional cost field allows the rider to record expenses directly into Finances.
