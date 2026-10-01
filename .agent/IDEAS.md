# Chaos Ideas

## Idea 1
Name: Random Currency Volatility Event
Description: Periodic server-wide events that randomly multiply or divide all player balances by a surprise factor (e.g., 2x, 0.5x, 3x, 0.2x).
Player interaction: Players must check their balance frequently to catch lucky spikes or minimize losses.
Why it could be fun: Creates urgency, adds unpredictability, and rewards or punishes active players.
Implementation scope: Add a scheduled event to CurrencyService that broadcasts multipliers and triggers balance updates.

## Idea 2
Name: Player Balance Warping
Description: When a player deposits currency, a random small percentage is "lost to the void" or "found by a stranger" instead of going to them.
Player interaction: Deposits become uncertain - sometimes you get less than expected, sometimes you get extra from the "void".
Why it could be fun: Adds chaos to the earning loop, encourages paranoia and experimentation, keeps players engaged.
Implementation scope: Modify the deposit logic in CurrencyService to randomly adjust final amounts with a small probability.

## Idea 3
Name: Phantom Withdrawals
Description: Occasionally, a player's balance shows as decreased when no actual withdrawal was made - a "phantom loss" that may or may not be reversible.
Player interaction: Players must investigate and petition support to recover phantom losses, creating engagement and FOMO.
Why it could be fun: Adds mystery and drama, creates player stories and community discussion, encourages social interaction.
Implementation scope: Add a scheduled event that randomly adjusts balances and logs "phantom" transactions for admin review.
