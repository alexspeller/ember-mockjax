# add configuration params for nested_params

(($) ->
  $.emberMockJax = (options) ->
    responseJSON = {}

    # defaults
    config =
      fixtures: {}
      factories: {}
      urls: ["*"]
      debug: false
      namespace: ""

    $.mockjaxSettings.logging = false


    $.extend config, options

    log = (msg, obj) ->
      if !obj
        obj = msg
        msg = "no message"

    error = (msg) ->
      console?.error "jQuery-Ember-MockJax ERROR: #{msg}"

    uniqueArray = (arr) ->
      arr = arr.map (k) ->
        k.toString() unless k is null
      $.grep arr, (v, k) ->
        $.inArray(v ,arr) == k

    getRequestType = (request) ->
      request.type.toLowerCase()

    splitUrl = (url) ->
      url.replace("/#{config.namespace}","").split("/")

    getModelName = (request) ->
      splitUrl(request.url).shift()

    getQueryParams = (request) ->
      id = splitUrl(request.url)[1]
      if getRequestType(request) is "put"
        request.data = JSON.parse(request.data)
        modelName = getModelName(request).attributize()
        request.data[modelName].id = parseInt(id) if id
      else
        request.data = [] if !request.data
        request.data.id = parseInt(id) if id

      request.data

    getRelationships = (modelName) ->
      Em.get(App[modelName.modelize()], "relationshipsByName")

    String::fixtureize = ->
      @pluralize().camelize().capitalize()

    String::resourceize = ->
      @pluralize().underscore()

    String::modelize = ->
      @singularize().camelize().capitalize()

    String::attributize = ->
      @singularize().underscore()

    findRecords = (modelName, params) ->
      fixtureName = modelName.fixtureize()
      error("Fixtures not found for Model : #{fixtureName}") unless config.fixtures[fixtureName]
      config.fixtures[fixtureName].filter (record) ->
        for param of params
          continue unless params.hasOwnProperty(param)
          if record[param] isnt params[param] and record[param]?
            return false
          else if param is "ids" and params[param].indexOf(record.id.toString()) < 0
            return false
        true

    buildResponseJSON = (modelName, queryParams) ->
      responseJSON[modelName] = findRecords(modelName, queryParams)
      getRelatedRecords(modelName)

    getRelationshipIds = (modelName, relatedModel, relationshipType) ->
      ids = []
      responseJSON[modelName].forEach (record) ->
        if relationshipType is "belongsTo"
          ids.push record["#{relatedModel.attributize()}_id"]
        else
          $.merge(ids, record["#{relatedModel.attributize()}_ids"])
      uniqueArray ids

    getRelatedRecords = (modelName) ->
      relationships = getRelationships(modelName)
      relationships.forEach (relatedModel, relationship) ->
        return if !relationship.options.async? or relationship.options.async is true
        params = []
        params["ids"] = getRelationshipIds(modelName, relatedModel, relationship.kind)
        responseJSON[relatedModel.resourceize()] = findRecords(relatedModel, params) 
        getRelatedRecords(relatedModel)

    getNextFixtureID = (modelName) ->
      config.fixtures[modelName.fixtureize()].slice(0).sort((a,b) -> b.id - a.id)[0].id + 1

    setDefaultValues = (request, modelName) ->
      record = JSON.parse(request.data)[modelName.attributize()]
      setRecordDefaults(record, modelName)

    setRecordDefaults = (record, modelName) ->
      record.id = getNextFixtureID(modelName)
      modelName.modelize()
      factory = getFactory(modelName)
      Object.keys(record).forEach (key) ->
        prop = record[key]
        def = factory[key.camelize()]?.default
        if typeof prop is "object" and prop is null and def
          record[key] = def
        else if typeof prop is "object" and prop isnt null
          record[key] = setRecordDefaults(record[key], key.replace("_attributes",""))
      record

    getFactory = (modelName) ->
      config.factories[modelName.fixtureize()]

    addRelatedRecordsToFixtures = (modelName, record) ->
      relationships = getRelationships(modelName)
      relationships.forEach (relatedModelName, relationship) ->
        attributeName = if relationship.kind is "hasMany" then relatedModelName.resourceize() else relatedModelName.attributize()
        attributeName += "_attributes"
        if relationship.options.nested and record[attributeName]?
          if relationship.kind is "hasMany"
            record["#{relatedModelName}_ids"] = []
            record[attributeName].forEach (relatedRecord) ->
              if relatedRecord.id?
                record["#{relatedModelName}_ids"].push addRecordToFixtures(relatedModelName, relatedRecord)
          else
            if record[attributeName].id?
              record["#{relatedModelName}_id"] = addRecordToFixtures(relatedModelName, record[attributeName])
          delete record[attributeName]

    addRecordToFixtures = (modelName, record) ->
      config.fixtures[modelName.fixtureize()].push(record)
      record.id

    getFixtureById = (fixtureName, id) ->
      config.fixtures[fixtureName.fixtureize()].filterBy("id", id).get("firstObject")

    $.mockjax
      url: "*"
      responseTime: 0
      response: (request) ->
        responseJSON    = {}
        requestType     = getRequestType(request)
        rootModelName   = getModelName(request)
        queryParams     = getQueryParams(request)

        if requestType is "post"
          new_record = setDefaultValues(request, rootModelName)
          addRelatedRecordsToFixtures(rootModelName, new_record)
          addRecordToFixtures(rootModelName, new_record)
          buildResponseJSON(rootModelName, queryParams)
        else if requestType is "put"
          update_record = getFixtureById(rootModelName, queryParams[rootModelName.attributize()].id)
          addRelatedRecordsToFixtures(rootModelName, update_record)

          # add related records to fixtures
          # update related records in fixtures
          # update root record

        else if requestType is "get"
          buildResponseJSON(rootModelName, queryParams)

        @responseText = responseJSON

        console.log "MOCK RSP:", request.url, @responseText if $.mockjaxSettings.logging

) jQuery


    # parseUrl = (url) ->
    #   parser = document.createElement('a')
    #   parser.href = url
    #   parser

    # addRelatedRecord = (fixtures, json, name, new_record, singleResourceName) ->
    #   json[name.resourceize()] = [] if typeof json[name.resourceize()] isnt "object"
    #   duplicated_record = $.extend(true, {}, fixtures[name.fixtureize()].slice(-1).pop())
    #   duplicated_record.id = parseInt(duplicated_record.id) + 1
    #   $.extend(duplicated_record,new_record[singleResourceName][name.underscore() + "_attributes"])
    #   fixtures[name.fixtureize()].push(duplicated_record)
    #   delete new_record[singleResourceName][name.underscore() + "_attributes"]
    #   new_record[singleResourceName][name.underscore().singularize() + "_id"] = duplicated_record.id
    #   json[name.resourceize()].push(duplicated_record)
    #   json

    # addRelatedRecords = (fixtures, json, name, new_record, singleResourceName) ->
    #   duplicated_record = undefined
    #   json[name.resourceize()] = []  if typeof json[name.resourceize()] isnt "object"
    #   new_record[singleResourceName][name.resourceize().singularize() + "_ids"] = []
    #   new_record[singleResourceName][name.resourceize() + "_attributes"].forEach (record) ->
    #     duplicated_record = $.extend(true, {}, fixtures[name.fixtureize()].slice(-1).pop())
    #     delete record.id

    #     $.extend duplicated_record, record
    #     duplicated_record.id = parseInt(duplicated_record.id) + 1
    #     fixtures[name.fixtureize()].push duplicated_record
    #     new_record[singleResourceName][name.resourceize().singularize() + "_ids"].push duplicated_record.id
    #     json[name.resourceize()].push duplicated_record
    #     return

    #   delete new_record[singleResourceName][name.resourceize() + "_attributes"]

    #   json

    # allPropsNull = (obj,msg) ->
    #   Object.keys(obj).every (key) ->
    #     if obj[key] isnt null and key not in ["archived", "type", "primary", "quantity"]
    #       allPropsNull obj[key] if typeof obj[key] is "object"
    #     else
    #       true

    # flattenObject = (obj,result) ->
    #   result = {} unless result
    #   keys = Object.keys(obj)
    #   keys.forEach (key) ->
    #     if obj[key] is null
    #       delete obj[key]
    #     else if typeof obj[key] is "object"
    #       result = flattenObject(obj[key],result)
    #     else
    #       result[key] = [obj[key]]
    #   result

    # setErrorMessages = (obj, msg, parentKeys) ->
    #   unless parentKeys
    #       parentKeys = []
    #       path = ""

    #   Object.keys(obj).every (key) ->
    #     if obj[key] isnt null and typeof obj[key] isnt "boolean"
    #       if typeof obj[key] is "object"
    #         parentKeys.push(key.replace("_attributes",""))
    #         obj[key] = setErrorMessages(obj[key], msg, parentKeys)
    #     else
    #       path = parentKeys.join(".") + "." if parentKeys.length
    #       obj["#{path}#{key}"] = "#{msg}"
    #   obj

    # buildErrorObject = (obj, msg) ->
    #   rootKey = Object.keys(obj).pop()
    #   obj["errors"] = flattenObject(setErrorMessages(obj[rootKey],msg))
    #   delete obj[rootKey]
    #   obj

    # sideloadRecords = (fixtures, name, parent, kind) ->
    #   temp = []
    #   params = []
    #   res = []
    #   parent.forEach (record) ->
    #     if kind is "belongsTo"
    #       res.push record[name.underscore().singularize() + "_id"]
    #     else
    #       $.merge(res, record[name.underscore().singularize() + "_ids"])

    #   params["ids"] = uniqueArray res
    #   records = findRecords(fixtures,name.capitalize().pluralize(),["ids"],params)

    # getRelatedModels = (resourceName, json) ->
    #   relationships = getRelationships(resourceName.modelize())
    #   relationships.forEach (name, relationship) ->
    #     if "async" in Object.keys(relationship.options)
    #       unless relationship.options.async
    #         json[name.pluralize()] = sideloadRecords(fixtures,name,json[resourceName],relationship.kind)
    #         getRelatedModels(name, fixtures, json)
    #   json

        # addRecord = (fixtures, json, new_record, fixtureName, resourceName, singleResourceName) ->
        #   duplicated_record = $.extend(true, {}, fixtures[fixtureName].slice(-1).pop())
        #   duplicated_record.id = parseInt(duplicated_record.id) + 1
        #   duplicated_record.archived_at = null
        #   $.extend(duplicated_record, new_record[singleResourceName])
        #   fixtures[fixtureName].push(duplicated_record)
        #   json[resourceName].push(duplicated_record)
        #   json

        #   # return error object if all values are null
        #   if allPropsNull(new_record)
        #     @status = 422
        #     @responseText = buildErrorObject(new_record, "can't be blank")
        #   else
        #     json[resourceName] = []
        #     emberRelationships.forEach (name,relationship) ->
        #       if "nested" in Object.keys(relationship.options)
        #         unless relationship.options.async
        #           if relationship.kind is "hasMany"
        #             json = addRelatedRecords(fixtures,json,name,new_record,singleResourceName)
        #           else
        #             json = addRelatedRecord(fixtures,json,name,new_record,singleResourceName)

        #     @responseText = addRecord(fixtures,json,new_record,fixtureName,resourceName,singleResourceName)

          # console.log modelName
          # findRecords(fixtureName)

          #   if queryParams.length
          #     json[resourceName] = findRecords(fixtures,fixtureName,queryParams,request.data)
          #   else
          #     json[resourceName] = fixtures[fixtureName]

          #   @responseText = getRelatedModels(resourceName, fixtures, json)

        # queryParams             = []
        # json                    = {}

        # requestType             = request.type.toLowerCase()
        # pathObject              = parseUrl(request.url)["pathname"].split("/")
        # modelName               = pathObject.slice(-1).pop()
        # putId                   = null

        # if /^[0-9]+$/.test modelName
        #   if requestType is "get"
        #     request.data = {} if typeof request.data is "undefined"
        #     request.data.ids = [modelName]

        #   if requestType is "put"
        #     putId = modelName

        #   modelName = pathObject.slice(-2).shift().modelize()

        # else
        #   modelName = modelName.modelize()

        # fixtureName             = modelName.fixtureize()
        # resourceName            = modelName.resourceize()
        # singleResourceName      = resourceName.singularize()
        # emberRelationships      = getRelationships(modelName)
        # fixtures                = settings.fixtures
        # queryParams             = Object.keys(request.data) if typeof request.data is "object"
        # modelAttributes         = Object.keys(App[modelName].prototype).filter (e) ->
        #                             true unless e is "constructor" or e in emberRelationships.keys.list

        # if requestType is "post"
        #   new_record = JSON.parse(request.data)

        #   # return error object if all values are null
        #   if allPropsNull(new_record)
        #     @status = 422
        #     @responseText = buildErrorObject(new_record, "can't be blank")
        #   else
        #     json[resourceName] = []
        #     emberRelationships.forEach (name,relationship) ->
        #       if "nested" in Object.keys(relationship.options)
        #         unless relationship.options.async
        #           if relationship.kind is "hasMany"
        #             json = addRelatedRecords(fixtures,json,name,new_record,singleResourceName)
        #           else
        #             json = addRelatedRecord(fixtures,json,name,new_record,singleResourceName)

        #     @responseText = addRecord(fixtures,json,new_record,fixtureName,resourceName,singleResourceName)

        # if requestType is "put"
        #   new_record = JSON.parse(request.data)
        #   json[resourceName] = []
        #   emberRelationships.forEach (name,relationship) ->
        #     if "nested" in Object.keys(relationship.options)
        #       unless relationship.options.async
        #         fixtures[name.fixtureize()].forEach (record) ->
        #           if record.id is parseInt(new_record[singleResourceName][name.underscore() + "_attributes"].id)
        #             $.extend(record, new_record[singleResourceName][name.underscore() + "_attributes"])
        #             json[name.resourceize()] = [] if typeof json[name.resourceize()] is "undefined"
        #             json[name.resourceize()].push(record)
        #         delete new_record[singleResourceName][name.underscore() + "_attributes"]

        #   fixtures[fixtureName].forEach (record) ->
        #     if record.id is parseInt(putId)
        #       json[resourceName] = [] if typeof json[resourceName] is "undefined"
        #       $.extend(record, new_record[singleResourceName])
        #       json[resourceName].push(record)

        #   @responseText = json

        # if requestType is "get"

        #   console.warn("Fixtures not found for Model : #{modelName}") unless fixtures[fixtureName]
        #   if queryParams.length
        #     json[resourceName] = findRecords(fixtures,fixtureName,queryParams,request.data)
        #   else
        #     json[resourceName] = fixtures[fixtureName]

        #   @responseText = getRelatedModels(resourceName, fixtures, json)

# findRecords = (fixtures, fixtureName, queryParams, requestData) ->
#   fixtures[fixtureName].filter (element, index) ->
#     matches = 0
#     for param in queryParams
#       scope_param = param.replace "by_", ""
#       if typeof requestData[param] is "object" and requestData[param] isnt null
#         if element[scope_param.singularize()].toString() in requestData[param] or element[scope_param.singularize()] in requestData[param]
#           matches += 1
#       else
#         matchParam = requestData[param]
#         matchParam = parseInt(requestData[param]) if typeof requestData[param] is "string" and typeof element[scope_param.singularize()] is "number"
#         matches += 1 if matchParam == element[scope_param.singularize()]
#     true if matches == queryParams.length