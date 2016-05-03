_.mixin (require 'underscore.string').exports()

{VERSION} = require '../urequire'

class Template

  constructor: ->

    #todo: improve this
    @getp = do (_this=@) ->
      (path, options={}) ->
        if not path
          _this
        else
          _B.getp _this, path, _.defaults(options, separator:'.')

    @setp = do (_this=@) ->
      (path, value, options={}) ->
        if not path
          _this
        else
          _B.setp _this, path, value, _.defaults(options, separator:'.')

  # Create the tamplate for "Immediately Invoked Function Expression", i.e :
  #   Declare a Function, given its codeBody, and invoke it with given param + value pairs
  #
  # @param {String} codeBody the code to invoke with IIFE
  #
  # @param {String...} paramValuePairs pairs of param + value with which to invoke
  #
  # @gotcha:  __functionIIFE isnt private, its a name convention!

  # @example
  #   __functionIIFE 'var a = root;', 'root', 'window', '$', 'jQuery'
  #     ---> (function (root, $) {
  #            var a = root;
  #           })(window, jQuery)
  __functionIIFE: (codeBody, paramValuePairs...) -> """
    (function (#{(param for param, i in paramValuePairs when i%2 is 0).join(', ')}) {
      #{codeBody}
    }).call(this#{if paramValuePairs.length>0 then ', ' else ''}#{
      (value for value, i in paramValuePairs when i%2 isnt 0).join(', ')
    })
  """

  # Declare a Function
  #
  # @param {String} codeBody the code to invoke with IIFE
  # @param {String...} params of param + value with which to invoke
  # @example
  #   __function "var a = root;", "root", "factory"
  #     ---> function (root, factory) {
  #            var a = root;
  #           }
  __function: (codeBody, params...) -> """
    function (#{(param for param, i in params).join(', ')}) {
      #{codeBody}
    }
    """
  deb: (debugLevel, str) ->
    if (@build?.template?.debugLevel or 0 ) >= debugLevel
      if str
        str = str.replace('\n',  ' | ')
        scopeInfo =
          "#{@scope}: " +
          (if @scope is 'module' then "'#{@module.path}', bundle: " else '') +
          "'#{@bundle.name}'"

        (if (@build?.template?.debugLevel or 0 ) >= (debugLevel * 10)
          "\n//uRequire: #{str} (#{scopeInfo})" +
          '\nconsole.log("\\n' +
              (if @scope is 'module' then '\\u001b[32m' else '\\u001b[33m') +
              'uRequire:' + str +
              ' ('+ scopeInfo + ')' +
          '");\n'
        else
          "\n//uRequire: #{str} (#{scopeInfo})\n"
        )
      else
        true
    else
      if str then '' else false

  # sectionsPrint
  #
  #  @param {Array} sections `sect in sections`, is either:
  #     String: name of section
  #     [<name, descr>]
  #     @function returning the above
  #     @todo: blend
  sp: (sections...) ->
    (for sect in sections
      if _.isFunction sect
        sect = sect()

      if _.isString sect
        name = sect
      else if _.isArray sect
        name = sect[0]
        descr = sect[1]
      else if _B.isHash sect
        {name, descr} = sect
      else
        name = undefined

      if name
        if (p = @getp name)
          startMsg = "## START ## of '#{name}' #{(': ' + descr if descr) or ''}"
          if @deb 10
            @deb(10, startMsg) + p + @deb(20, "## END ## of '#{name}'")
          else
            "\n#{p}\n"
        else ''
      else ''
    ).join('')

  Object.defineProperties @::,

    uRequireBanner: get:->
      """// Generated by uRequire v#{VERSION} #{if @build.target then "target: '"+@build.target+"'" else ''} template: '#{@build.template.name}'\n"""

    runtimeInfo: get:-> """
        var __isAMD = !!(typeof define === 'function' && define.amd),
            __isNode = (typeof exports === 'object'),
            __isWeb = !__isNode;
      """ +

      ( if @deb(50)
          "\nconsole.log('uRequire: runtimeInfo:\\n__isAMD=', __isAMD, '\\n__isNode=', __isNode, '\\n__isWeb=', __isWeb);"
        else ''
      )

    globalSelector: get:->
      "(typeof exports === 'object' || typeof window === 'undefined' ? global : window)"

module.exports = Template
