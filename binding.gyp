{
  "targets": [
    {
      "target_name": "panda_secure_addon",
      "sources": [ "native-src/addon.cpp" ],
      "include_dirs": [
        "<!(node -e \"require('node-addon-api'); console.log(require('node-addon-api').include)\")"
      ],
      "dependencies": [
        "node_modules/node-addon-api/node_addon_api.gyp:node_addon_api"
      ],
      "defines": [ "NAPI_DISABLE_CPP_EXCEPTIONS" ]
    }
  ]
}