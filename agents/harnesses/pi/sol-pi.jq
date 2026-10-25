# Reject incompatible inputs; never authorize a separate diagnostic-log model call. [D-PI-WEB]
if type != "object" then error("SoL-Pi config must be an object") else . end
| if ((keys - ["version", "actionFusion", "observationPack", "evidencePreservingReducer",
    "evidencePreservingReducerProvider", "evidencePreservingReducerModel",
    "onlineContextCompact", "cacheWriteReadRatio"]) | length) != 0
  then error("Unknown SoL-Pi config key") else . end
| if has("version") and .version != 1 then error("Unsupported SoL-Pi config version") else . end
| if any(to_entries[]; (.key | IN("actionFusion", "observationPack", "evidencePreservingReducer", "onlineContextCompact")) and (.value | type) != "boolean")
  then error("SoL-Pi feature flags must be boolean") else . end
| if any(to_entries[]; (.key | IN("evidencePreservingReducerProvider", "evidencePreservingReducerModel")) and (.value | if type == "string" then test("^\\s*$") else true end))
  then error("SoL-Pi reducer route must contain non-empty strings") else . end
| if has("cacheWriteReadRatio") and (.cacheWriteReadRatio | if type == "number" then (. < 0 or isinfinite or isnan) else true end)
  then error("SoL-Pi cache ratio must be finite and non-negative") else . end
| . * {
  "version": 1,
  "actionFusion": true,
  "observationPack": true,
  "evidencePreservingReducer": false,
  "onlineContextCompact": true,
  "cacheWriteReadRatio": 12.5
}
