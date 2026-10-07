# Sourced by tools/build-{ios,android,windows}.sh: names that depend on
# which client is built ($CLIENT: client3d = 3D, client = 2D).
#   NAME     release file prefix (StartupSim3D-<version>-... / StartupSim-<version>-...)
#   APP_ID   iOS bundle id and Android package
#   DIR_TAG  build/ subfolder suffix, so the two clients' builds never mix
case "$CLIENT" in
  client3d) NAME=StartupSim3D; APP_ID=pl.mateuszpalak.startupsim3d; DIR_TAG="" ;;
  client) NAME=StartupSim; APP_ID=pl.mateuszpalak.startupsim; DIR_TAG=2d ;;
  *) echo "CLIENT=$CLIENT? (client3d albo client)"; exit 1 ;;
esac
