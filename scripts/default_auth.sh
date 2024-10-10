#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

export RPC_URL="http://localhost:5050"

# export WORLD_ADDRESS=$(cat ./manifests/dev/manifest.json | jq -r '.world.address')
# export ACTION_ADDRESS=$(cat ./manifests/dev/manifest.json | jq -r '.contracts[] | select(.name == "dragark_2::systems::actions::actions" ).address')
export WORLD_ADDRESS="0x4fc36d4c2cfac55877f99f973079673d593baf79807765d802270bd4a058f2d"
export ACTION_ADDRESS="0x2d7e04c80d1407b843368a5708072d30c7966918286e77fb4ae7ef06c758b86"

echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS
echo action : $ACTION_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> models authorizations

# enable system -> component authorizations
MODELS=("BaseResources" "Dragon" "Island"
         "Journey" "MapInfo" "Mission" "MissionTracking" 
         "NextBlockDirection" "NextIslandBlockDirection" "NonceUsed" 
         "Player" "PlayerDragonOwned" "PlayerGlobal" "PlayerIslandOwned" 
         "PlayerIslandSlot" "PlayerScoutInfo" "PositionIsland" "ScoutInfo" "Shield"
         "Achievement" "AchievementTracking")
ACTIONS=($ACTION_ADDRESS)

command="sozo auth grant --world $WORLD_ADDRESS --wait writer "
for model in "${MODELS[@]}"; do
    for action in "${ACTIONS[@]}"; do
        command+="$model,$action "
    done
done
eval "$command"

echo "Default authorizations have been successfully set."