# Preserve credentials and unrelated options; explicit providers bypass fallback. [D-PI-WEB]
del(.provider, .searchProvider)
| . * {
  "webSearch": { "enabled": true, "allowedProviders": ["openai", "exa"] },
  "searchRouting": {
    "providers": ["openai", "exa"],
    "fallbackOn": ["unsupported", "transient", "quota", "network", "invalid-response"]
  },
  "openaiSearchProviders": ["openai"],
  "openaiSearchModel": "gpt-6-luna",
  "openaiUseAlphaSearch": false,
  "summaryModel": "openai/gpt-6-luna",
  "workflow": "none",
  "allowBrowserCookies": false,
  "tools": {
    "webSearch": { "enabled": true },
    "sourceCheck": { "enabled": true },
    "fetchContent": { "enabled": true },
    "getSearchContent": { "enabled": true }
  },
  "fetchRouting": { "providers": ["http", "jina"], "allowRemoteHostedProviders": true },
  "fetch": {
    "defaultMode": "readable",
    "allowedModes": ["readable", "raw", "answer"],
    "answerProvider": "openai",
    "answerModel": "gpt-6-luna"
  },
  "image": { "enabled": true },
  "pdf": { "enabled": true, "provider": "unpdf", "maxSizeMB": 20, "maxPages": 100 },
  "githubClone": { "enabled": true },
  "githubPrIssue": { "enabled": true },
  "youtube": { "enabled": true },
  "video": { "enabled": true }
}
