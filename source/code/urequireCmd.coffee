_ = require 'lodash'
_B = require 'uberscore'
_fs = require 'fs'
_wrench = require "wrench"

urequireCmd = require 'commander'
upath = require './paths/upath'
Build = require './process/Build'

Logger = require './utils/Logger'
l = new Logger 'urequireCMD'

# helpers
toArray = (val)-> val.split(',')

config = {}

urequireCmd
#  .version(( JSON.parse require('fs').readFileSync "#{__dirname}/../../package.json", 'utf-8' ).version)
#  .usage('<templateName> <bundlePath> [options]')
  .version(l.VERSION) # 'var version = xxx' written by grunt's banner
  .option('-o, --outputPath <outputPath>', 'Output converted files onto this directory')
  .option('-f, --forceOverwriteSources', 'Overwrite *source* files (-o not needed & ignored)', undefined)
  .option('-v, --verbose', 'Print module processing information', undefined)
  .option('-d, --debugLevel <debugLevel>', 'Pring debug information (0-100)', 0)
  .option('-n, --noExports', 'Ignore all web `rootExports` in module definitions', undefined)
  .option('-r, --webRootMap <webRootMap>', "Where to map `/` when running in node. On RequireJS its http-server's root. Can be absolute or relative to bundle. Defaults to bundle.", undefined)
  .option('-s, --scanAllow', "By default, ALL require('') deps appear on []. to prevent RequireJS to scan @ runtime. With --s you can allow `require('')` scan @ runtime, for source modules that have no [] deps (eg nodejs source modules).", undefined)
  .option('-a, --allNodeRequires', 'Pre-require all deps on node, even if they arent mapped to parameters, just like in AMD deps []. Preserves same loading order, but a possible slower starting up. They are cached nevertheless, so you might gain speed later.', undefined)
  .option('-C --continue', 'NOT IMPLEMENTED Dont bail out while processing (mainly on module processing errors)', undefined)
  .option('-u, --uglify', 'NOT IMPLEMENTED. Pass through uglify before saving.', undefined)
  .option('-w, --watch', 'NOT IMPLEMENTED. Watch for changes in bundle files and reprocess those changed files.', undefined)
  .option('-i, --include', "NOT IMPLEMENTED. Process only modules/files in filters - comma seprated list/Array of Strings or Regexp's", toArray)
  .option('-j, --jsonOnly', 'NOT IMPLEMENTED. Output everything on stdout using json only. Usefull if you are building build tools', undefined)
  .option('-e, --verifyExternals', 'NOT IMPLEMENTED. Verify external dependencies exist on file system.', undefined)
  .option('-t, --template <template>', 'Template (AMD, UMD, nodejs), to override a `configFile` setting. Should use ONLY with `config`', undefined)

for tmplt in Build.templates #['AMD', 'UMD', 'nodejs', 'combine']
  do (tmplt)->
    urequireCmd
      .command("#{tmplt} <bundlePath>")
      .description("Converts all modules in <bundlePath> using '#{tmplt}' template.")
      .action (bundlePath)->
        config.template = tmplt
        config.bundlePath = bundlePath

urequireCmd
  .command('config <configFiles...>')
  .action (cfgFiles)->
    config.configFiles = toArray cfgFiles

urequireCmd.on '--help', ->
  console.log """
  Examples:
                                                                  \u001b[32m
    $ urequire UMD path/to/amd/moduleBundle -o umd/moduleBundle   \u001b[0m
                    or                                            \u001b[32m
    $ urequire UMD path/to/moduleBundle -f                        \u001b[0m

  Module files in your bundle can conform to the standard AMD format:
      // standard anonymous modules format                  \u001b[33m
    - define(['dep1', 'dep2'], function(dep1, dep2) {...})  \u001b[0m
                            or
      // named modules also work, but are NOT recommended                 \u001b[33m
    - define('moduleName', ['dep1', 'dep2'], function(dep1, dep2) {...})  \u001b[0m

    A 'relaxed' format can be used, see the docs.

  Alternativelly modules can use the nodejs module format:
    - var dep1 = require('dep1');
      var dep2 = require('dep2');
      ...
      module.exports = {my: 'module'}

  Notes:
    --forceOverwriteSources (-f) is useful if your sources are not `real sources`
      eg. you use coffeescript :-).
      WARNING: -f ignores --outputPath
"""
urequireCmd.parse process.argv

#hack to get cmd options only ['verbose', 'scanAllow', 'outputPath', ...] etc
CMDOPTIONS = _.map(urequireCmd.options, (o)-> o.long.slice 2)

# overwrite anything on config's root by cmdConfig - BundleBuilder handles the rest
_.extend config, _.pick(urequireCmd, CMDOPTIONS)

if config.verbose or true
  l.verbose 'uRequire called with cmdConfig=\n', config

#new (require './urequire').BundleBuilder config