takenncs-boosting

DESCRIPTION:
A complete vehicle theft and delivery system for FiveM servers using QBCore framework. Players can accept boosting contracts, steal specified vehicles, and deliver them to NPC buyers for rewards and XP progression.

FEATURES:
- Contract-based mission system
- Queue system for job distribution
- Randomized vehicle assignments with unique plates
- Multiple configurable spawn locations
- NPC delivery points with ox_target interaction
- XP progression with multiple skill levels
- Reward scaling based on performance
- ox_inventory tablet integration
- lb-phone email notifications
- Comprehensive admin controls

INSTALLATION:

1. Add to resources:
   cd resources
   git clone https://github.com/your-repo/takenncs-boosting

2. Database setup (MySQL):
   CREATE TABLE IF NOT EXISTS `takenncs-boosting` (
     `charId` VARCHAR(255) NOT NULL,
     `xp` INT DEFAULT 0,
     `finished` INT DEFAULT 0,
     PRIMARY KEY (`charId`)
   );

3. Add to server.cfg:
   ensure takenncs-boosting

4. Configure ox_inventory item:
   ['takenncs-tablet'] = {
       label = 'Kahtlane Tahvel',
       weight = 0,
       description = 'Süsteemid ootavad?',
       client = {
           export = 'takenncs-boosting.openTablet',
       }
   },

CONFIGURATION (config.lua):
Config = {
    ContractTime = { min = 5, max = 10 }, -- Minutes between contracts
    LevelReward = { min = 10, max = 25 }, -- XP range per job
    VehicleSpawns = {
        vector4(1153.39, -1410.96, 34.70, 93.54),
        -- Additional spawn locations
    },
    DeliveryPoints = {
        vector4(1958.90, 3836.79, 32.02, 351.49),
        -- Additional delivery points
    },
    Levels = {
        { label = "Rookie", xp = 0, procentage = 1.0 },
        { label = "Pro", xp = 100, procentage = 1.5 },
        -- Additional levels
    }
}

USAGE:

Player Commands:
- Use the boosting tablet item to access interface
- Join queue to receive contracts
- Accept available contracts
- Locate and steal target vehicle
- Deliver to specified NPC location

Admin Commands:
/giveboost [playerId] [model] - Assign boost contract
/clearboostcontract [playerId] [contractId] - Cancel contract

TECHNICAL ARCHITECTURE:

Client-Side:
- Vehicle spawning/despawning
- Blip and marker management
- Player interaction handling
- Tablet UI functionality

Server-Side:
- Contract generation system
- Reward distribution
- XP calculations
- Database operations

TROUBLESHOOTING:

Issue: Contracts not appearing
Solution: Verify queue system is active in config

Issue: NPC not accepting vehicle
Solution: Check plate matching system

Issue: Payment failures
Solution: Verify ox_inventory money item exists

LICENSE:
MIT License - See LICENSE file for details
