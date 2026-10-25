# Pi owns settings/auth/theme state; assert only model defaults and our npm package. [D-PI-WEB]
.defaultProvider = "openai"
| .defaultModel = "gpt-6.1-sol"
| .packages = ((.packages // []) | map(select(
    (if type == "string" then . else .source end | test("^npm:pi-web-access(@|$)")) | not
  )) + ["npm:pi-web-access@0.35.0"])
