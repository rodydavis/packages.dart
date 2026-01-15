/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("XTpascjA7jyzB88")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.id != ''",
    "viewRule": "@request.auth.id != ''"
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("XTpascjA7jyzB88")

  // update collection data
  unmarshal({
    "listRule": "@request.auth.id = author",
    "viewRule": "@request.auth.id = author"
  }, collection)

  return app.save(collection)
})
