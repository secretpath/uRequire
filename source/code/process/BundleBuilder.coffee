_ = require 'lodash'
_ = require 'lodash'
fs = require 'fs'
_B = require 'uberscore'

l = new _B.Logger 'urequire/BundleBuilder'

# urequire
upath = require '../paths/upath'
uRequireConfigMasterDefaults = require '../config/uRequireConfigMasterDefaults'
blendConfigs = require '../config/blendConfigs'
UError = require '../utils/UError'

###
  Load config :
    * check options
    * Load (a) bundle(s) and (a) build(s)
    * Build & watch for changes
###
class BundleBuilder

  constructor: (@configs, deriveLoader)->

    configs.push uRequireConfigMasterDefaults # add as the last one - the defaults on which we lay our more specifics
    finalCfg = blendConfigs configs, deriveLoader

    # we now have our 'final' USER config
    @bundleCfg = finalCfg.bundle
    @buildCfg = finalCfg.build
    @buildCfg.done = configs[0]?.done or ->l.log 'where s my done1?' # @todo: remove / test user configable

    # verbose / debug anyone ?
    if @buildCfg.debugLevel?
      _B.Logger.setDebugLevel @buildCfg.debugLevel, 'urequire'
      l.debug 0, "Setting userCfg _B.Logger.setDebugLevel(#{@buildCfg.debugLevel}, 'urequire')"

    if not @buildCfg.verbose
      if @buildCfg.debugLevel >= 50
        l.warn 'Enabling verbose, because debugLevel >= 50'
      else
        _B.Logger::verbose = -> #todo: travesty! 'verbose' should be like debugLevel ?

    l.verbose 'uRequire v'+l.VERSION + ' initializing...'

    # display userCfgs, WITHOUT applying master defaults
    l.debug("user config :\n",
      blendConfigs(configs[0..configs.length-2], deriveLoader)) if l.deb 40

    # display full cfgs, having applied master defaults.
    l.debug("final config :\n", finalCfg) if l.deb 20

    ### Lets check & fix different formats or quit if we have anomalies ###
    # Why these here instead of top ? # Cause We need to have _B.Logging.debugLevel ready BEFORE YADC debug check
    # Why on @ ? Cause we need them outside constructor, below
    @Bundle = require './Bundle'
    @Build = require './Build'

    if @isCheckAndFixPaths() and @isCheckTemplate()
      # Create the implementation instance from these configs @todo: refactor / redesign this / better practice ?
      try
        @bundle = new @Bundle @bundleCfg
        @build = new @Build @buildCfg
      catch err
        l.err uerr = "Initializing @bundle or @build", err
        throw new UError uerr, nested:err

    else # something went wrong with paths, template etc # @todo:2,4 add more fixes/checks ?
      @buildCfg.done false

  buildBundle: (filenames)->
    if not (!@build or !@bundle)
      @bundle.buildChangedResources @build, filenames
    else
      l.err "buildBundle(): I have !@build or !@bundle - can't build!"
      @buildCfg.done false


  watch: ->
    bundleBuilder = this
    watchFiles = []; watchDirs = []
    gaze = require 'gaze'
    path = require 'path'
    fs = require 'fs'

#    #@todo build this according to watch.filez || bundle.filez
#    watchedFiles =  _.map bundleBuilder.bundle.filenames, (file)->
#      path.join bundleBuilder.bundle.path, file
#    watchedFiles.unshift bundleBuilder.bundle.path + '/**/*.*' # all dirs
    gaze bundleBuilder.bundle.path + '/**/*.*', (err, watcher)->
      l.log 'Watching started...'
      watcher.on 'all', (event, filepath)->
        if event isnt 'deleted'
          try
            filepathStat = fs.statSync filepath # i.e '/mnt/dir/mybundle/myfile.js'
          catch err

        filepath = path.relative process.cwd(), filepath # i.e 'mybundle/myfile.js'

        if filepathStat?.isDirectory()
          l.log "Adding '#{filepath}' as new watch directory is NOT SUPPORTED yet."
#          _.delay addDirs, 500 if _.isEmpty watchDirs
#          watchDirs.push filepath + '/**/*.*'
        else
          l.log "Watch file '#{filepath}' has #{event}."
          _.delay runBuildBundle, 500 if _.isEmpty watchFiles
          watchFiles.push path.relative bundleBuilder.bundle.path, filepath

      addDirs = ()->
        watcher.add dir for dir in watchDirs # gaze crashes on 'watcher.add'
        watchDirs = []

      runBuildBundle = ->
        if not _.isEmpty watchFiles
          bundleBuilder.buildBundle watchFiles
          watchFiles = []
        else
          l.warn 'EMPTY watchFiles = ', watchFiles
        l.log 'Watching again...'

  # check if template is Ok - @todo: (2,3,3) embed checks in blenders ?
  isCheckTemplate: ->
    if @buildCfg.template.name not in @Build.templates
      l.err """
        Quitting build, invalid template '#{@buildCfg.template.name}' specified.
        Use -h for help"""
      return false

    return true

  isCheckAndFixPaths: ->
    if not @bundleCfg?.path?
      # assume path, from the 1st configFile that came along
      if cfgFile = @configs[0]?.derive?[0]
        if dirName = upath.dirname cfgFile
          l.warn "Assuming path = '#{dirName}' from 1st configFile: '#{cfgFile}'"
          @bundleCfg.path = dirName
          return true
        else
          l.err "Assuming path = '#{upath.dirname cfgFile}' from 1st configFile: '#{cfgFile}'"
          return false
      else
        l.err """
          Quitting build, no path specified.
          Use -h for help"""
        return false
    else
      if @buildCfg.forceOverwriteSources
        @buildCfg.dstPath = @bundleCfg.path
        l.verbose "Forced output to '#{@buildCfg.dstPath}'"
        return true
      else
        if not @buildCfg.dstPath
          l.err """
            Quitting build, no --dstPath specified.
            Use -f *with caution* to overwrite sources (no need to specify & ignored --dstPath)."""
          return false
        else
          if upath.normalize(@buildCfg.dstPath) is upath.normalize(@bundleCfg.path)
            l.err """
              Quitting build, dstPath === path.
              Use -f *with caution* to overwrite sources (no need to specify & ignored --dstPath).
              """
            return false

    return true

module.exports = BundleBuilder

### Debug information ###

#if l.deb > 10 #or true
#  YADC = require('YouAreDaChef').YouAreDaChef
#
#  YADC(BundleBuilder)
#    .before /_constructor/, (match, config)->
#      l.debug(1, "Before '#{match}' with config = ", config)