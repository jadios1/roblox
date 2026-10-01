# Chaos Ideas

## Idea 1
Name: Random Balance Tax/Boon Event
Description: Every 5-10 minutes, a random server-wide event triggers that randomly adds or removes 5-50% of player balances based on their current amount.
Player interaction: Players see a system message announcing the event and instantly feel their balance change with a visual effect in the GUI.
Why it could be fun: Creates shared chaos moments, encourages players to time their play sessions, and adds unpredictable variance to progression.
Implementation scope: Add a timer hook in CurrencyService with random event logic, modify existing deposit/withdraw UI to show percentage changes, add a system message service.

## Idea 2
Name: Balance Vacuum
Description: When any player's balance exceeds 1000, trigger a "vacuum" that steals 10% of that player's balance and distributes it randomly among 3 other random players.
Player interaction: The triggering player sees their balance drop with a humorous message, while others receive deposits with "vacuumed from" attribution.
Why it could be fun: Creates social tension and rivalry, prevents early-game hoarding from becoming boring, and makes the economy feel alive and interconnected.
Implementation scope: Extend CurrencyService with a threshold check before deposit, modify existing deposit logic to support "stealed" deposits, add random player selection and notification logic.

## Idea 3
Name: Temporary Balance Flip
Description: Randomly select one player every 30 seconds to "flip" their balance display for 10 seconds (shows a funny multiplier like "x10" or "x0.1" of their real balance).
Player interaction: The affected player sees their displayed balance multiplied by a random factor for 10 seconds, while others see the funny display too.
Why it could be fun: Creates confusion and laughter, adds a psychological twist to the economy, and makes the currency system feel more chaotic and less serious.
Implementation scope: Add a player selection hook in CurrencyService, modify client-side balance rendering to show temporary multiplier, add a timeout callback to restore the real value.
