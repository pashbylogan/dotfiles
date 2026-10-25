# Pi owns mutable state; replace only our package identities and model defaults. [D-PI-WEB]
.defaultProvider = "openai"
| .defaultModel = "gpt-6.1-sol"
| .packages = ((.packages // []) | map(select(
    (if type == "string" then . else .source end
      | test("^npm:(pi-web-access|sol-pi)(@|$)|^(git:)?(https://)?github\\.com/NVlabs/SoL-Pi(\\.git)?(@|$)")) | not
  )) + [
    "npm:pi-web-access@0.44.0",
    "git:github.com/NVlabs/SoL-Pi@219568034fa54ed121ede80961655e33dfb9d0e3"
  ])
