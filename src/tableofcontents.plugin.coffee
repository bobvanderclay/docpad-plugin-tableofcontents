# Item for Table of Contents.
class TableofcontentsItem
    constructor: (@text, @id, @parent) ->
        @children = []

        if @parent?
            parent.children.push @

    add: (text, id) ->
        child = new TableofcontentsItem text, id, @

    text: ->
        @text or null

    id: ->
        @id or null

    submenu: ->
        @children
        

# Export Plugin
module.exports = (BasePlugin) ->
    # Requires
    jsdom = require('jsdom')


    # Define Plugin
    class TableofcontentsPlugin extends BasePlugin
        # Plugin name
        name: 'tableofcontents'

        # Plugin configuration
        config:
            # Which document extentions to search and generate.
            # For now, only html is supported.
            documentExtensions: ["html"]

            # Is a metadata field required?
            requireMetadata: false
            # If true, specify required metadata field. Set this field to true.
            requiredMetadataField: 'toc'

            # Add missing header id tags for ToC links.
            addHeaderIds: true
            
            # List of header elements to search.
            headerSelectors: 'h2,h3,h4,h5'

            # Which header level should we start with. 
            rootHeaderLevel: 2

        # Locale
        locale:
            parsingTocHeaders: "Parsing ToC headers: "
            buildingToc: "Building ToC: "

        buildTableofcontents: (window,headers) ->
            # Prepare
            config = @config

            # Setup
            currentLevel = (config.rootHeaderLevel - 1) # Root node is one higher
            tableofcontents = new TableofcontentsItem
            currentItem = tableofcontents

            # Build ToC List
            for value,key in headers
                header = headers.item(key)
                level = parseInt(header.tagName.charAt(1),10)

                if config.addHeaderIds
                    if not header.id
                        # Build header id based on header title.
                        # TODO: Check for uniqueness.
                        headerText = header.innerHTML
                        header.id = headerText.replace(/[^a-zA-Z0-9]/g,'-').replace(/^-/,'').replace(/-+/,'-')
                        
                # Move up and down tree as necessary.
                if level > currentLevel # down
                    # Fill in missing empty intermediate levels.
                    while level > (currentLevel + 1)
                        currentItem = currentItem.add("", "")
                        currentLevel++
                    currentLevel++

                else if level is currentLevel # same
                    currentItem = currentItem.parent
                    
                else if level < currentLevel # up
                    while level < currentLevel
                        currentItem = currentItem.parent
                        currentLevel--
                    currentItem = currentItem.parent

                # Add Item to ToC
                currentItem = currentItem.add(header.innerHTML, header.id)

            return tableofcontents

            
        # Render Before, make sure we have required metadata placeholders
        renderBefore: (opts,next) ->
            # Prepare
            documents = @docpad.getCollection(@config.collectionName or 'documents')
            config = @config
            locale = @locale

            # Cycle through all our documents
            documents.forEach (document) ->
                tableOfContents = document.tableOfContents? or []
                document.set(tableOfContents: tableOfContents)

                if config.requireMetadata
                    requiredMetadataFieldValue = document[config.requiredMetadataField]? or []
                    document[config.requiredMetadataField] = requiredMetadataFieldValue

            # All done
            return next()


        # Render the document
        renderDocument: (opts,next) ->
            # Prepare
            {extension,templateData,file,content} = opts
            me = @
            docpad = @docpad
            config = @config
            locale = @locale
            document = templateData.document

            # Handle
            if file.type is 'document' and extension in config.documentExtensions
                if not config.requireMetadata or document[config.requiredMetadataField]
                    # Log
                    docpad.log('debug', locale.parsingTocHeaders+document.name)

                    # Create DOM from the file content
                    jsdom.env(
                        html: "<html><body>#{opts.content}</body></html>"
                        features:
                            QuerySelector: true
                        done: (err,window) ->
                            # Check
                            return next(err)  if err

                            # Find headers
                            headers = window.document.querySelectorAll(config.headerSelectors)

                            # Check
                            if headers.length is 0
                                return next()

                            # Log
                            docpad.log('debug', locale.buildingToc+document.name)

                            # Build Table of Contents
                            toc = me.buildTableofcontents(window, headers)

                            # Only if we added header ids, update content.
                            if config.addHeaderIds
                                opts.content = window.document.body.innerHTML

                            # Update docment with contents.
                            document.tableOfContents = toc.submenu();

                            return next()
                    )

                else
                    return next()

            else
                return next()