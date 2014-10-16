_ = (_B = require 'uberscore')._
l = new _B.Logger 'uRequire/urequire/urequire-spec', 1

chai = require 'chai'
chai.use require 'chai-as-promised'
expect = chai.expect

{ equal, notEqual, ok, notOk, tru, fals, deepEqual, notDeepEqual, exact, notExact, iqual, notIqual
ixact, notIxact, like, notLike, likeBA, notLikeBA, equalSet, notEqualSet } = require '../specHelpers'

When = require 'when'
fs = require "fs"

logPromise = require('../../code/promises/logPromise') l
execP = When.node.lift require("child_process").exec
logExecP = logPromise execP, 'exec', 'stdout', 'stderr'

mkdirP = When.node.lift require 'mkdirp'
rimraf = require 'rimraf'

urequire = require '../../code/urequire'
UError = require '../../code/utils/UError'

globExpand = require 'glob-expand'

BundleFile = require '../../code/fileResources/BundleFile'

example = 'urequire-example'
exampleDir = "../#{example}"
exampleTemp = "temp/#{example}"

describe "urequire BundleBuilder:", ->
  bb = undefined
  defaultConfig = undefined

  VERSION = JSON.parse(fs.readFileSync process.cwd() + '/package.json').version

  before "Finding or `git clone` `#{exampleDir}`", ->
    (fs.existsP(exampleDir).then (isExists)->
      if isExists
        l.ok "Example repo exists in `#{exampleDir}`"
        When()
      else
        l.warn "Cloning repo anodynos/#{example} in `../`"
        logExecP("git clone https://github.com/anodynos/#{example}", cwd: '../').then ->
          logExecP("git checkout eefa27bd292d97c6f5de982c8b17a03c033844cc", cwd: exampleDir)
    )
      .then ->
        l.deb "Deleting 'temp'"
        rimraf.sync 'temp'
        l.deb "Copying source files from '#{ exampleDir }' to '#{exampleTemp}':"
        copyFiles = (
           _.filter globExpand({cwd: exampleDir + '/source', filter: 'isFile'}, ['**/*'])
          ).map((f)->'source/'+f).concat _.filter globExpand({cwd: exampleDir, filter: 'isFile'}, ['*'])

        for file in copyFiles
          BundleFile.copy exampleDir + '/' + file, exampleTemp + '/' + file

  afterBuildResults = null

  defaultConfig =
    path: "#{exampleTemp}/source/code"
    dependencies: exports: bundle: lodash: ['_']
    main: "urequire-example"

    resources: [
        # disable `coffee-script` RC & replace with `coffee-script-exec`
        (lookup)->
          (cf = lookup 'coffee-script').enabled = false

          _.extend lookup('exec').clone(), {
            name: '$coffee-script-exec'
            filez: cf.filez
            cmd: 'coffee -cp'
            convFilename: '.js'
          }

        # instead of 'inject-version', test a promise injectVERSION
        [ '+injectVERSIONPromises', 'An injectVERSION that returns a promise instead of sync', ['urequire-example.js'],
          (m)-> When().delay(0).then -> m.beforeBody = "var VERSION = '#{VERSION }';" ]

        [ '!injectTestAsync', 'An inject test that runs async', ['urequire-example.js'],
          (m, cb)-> setTimeout -> cb null, "'testASync';" + m.converted ]

        [ '!injectTestSync', 'An inject test that runs synchronously', ['urequire-example.js'],
          (m)-> "'testSync';" + m.converted ]

        ['less', { # ['style/**/*.less'], {
            $srcMain: 'style/myMainStyle.less'
            compress: true
        }]
    ]
    clean: true
    debugLevel: 0

    done:[
      -> afterBuildResults.push 'done0': arguments[0]
      (doneVal)-> afterBuildResults.push 'done1': doneVal
      (err, bb)-> When().delay(0).then -> afterBuildResults.push 'done2' : [err, bb]
      (err, bb, cb) -> setTimeout -> afterBuildResults.push 'done3' : [err, bb] ; cb null
    ]

  describe "`BundleBuilder.buildBundle` :", ->
    tests = [
        cfg:
          template: 'UMDplain'
          dstPath: "#{exampleTemp}/build/UMDplain"
        mylib: "#{exampleTemp}/build/UMDplain/urequire-example.js"
      ,
        cfg:
          template: 'nodejs'
          dstPath: "#{exampleTemp}/build/nodejs"
        mylib: "#{exampleTemp}/build/nodejs/urequire-example.js"
      ,
        cfg:
          template: 'combined'
          dstPath: "#{exampleTemp}/build/combined/urequire-example"
        mylib: "#{exampleTemp}/build/combined/urequire-example.js"
    ]

    buildLib = null
    global_urequireExample = 'global': 'urequireExample'
    global_uEx = 'global': 'uEx'

    describe "builds all files in `#{exampleTemp}/source/code` :", ->
      for test in tests
        do (test, cfg = test.cfg, mylib = test.mylib)->

          buildResult = null

          describe "with `#{cfg.template}` template:", ->

            before ->
              bb = new urequire.BundleBuilder [cfg, defaultConfig]
              afterBuildResults = []
              bbP = bb.buildBundle()

              bbP.then (res)->
                buildResult = res
                afterBuildResults.push "then1": res
                global.urequireExample = global_urequireExample
                global.uEx = global_uEx
                buildLib = require '../../../' + mylib

              bbP.then (res)-> afterBuildResults.push "then2": res

            it "initialized correctly from a defaultConfig", ->
              tru _B.isHash bb.bundle #todo: test more
              tru _B.isHash bb.build
              equal bb.build.template.name, cfg.template

            it "bb.buildBundle().then (res)-> res is bundleBuilder", ->
              equal buildResult, bb

            describe "bundleBuilder.bundle has the correct:", ->
              it "`all_depsVars`", ->
                deepEqual buildResult.bundle.all_depsVars,
                  "calc/add": ["add" ]
                  "calc/index": [ "calc" ]
                  "calc/multiply": []
                  "lodash": [ "_" ]
                  "models/Animal": [ "Animal" ]
                  "models/Person": [ "Person" ]

            describe "afterBuild tasks:", ->
              it "done() tasks are called once each, in serial order, followed by .then tasks:", ->
                deepEqual afterBuildResults, [
                  {'done0' : true}
                  {'done1' : true}
                  {'done2' : [null, bb]}
                  {'done3' : [null, bb]}
                  {'then1' : bb}
                  {'then2' : bb}
                ]

            describe "ResourceConverters work sync & async", ->

              it "lib has VERSION (injected via a promise returning RC)", ->
                  equal buildLib.VERSION, VERSION

              it "injection as async & sync RC work in the right order", ->
                if cfg.template isnt 'combined'
                  fs.readFileP(mylib, 'utf8').then (content)->
                    tru _.startsWith content, "'testSync';'testASync';"

              describe "'less' RC compiles to css:", ->

                it "with {options: compress: true}:", ->
                  expect(fs.readFileP "#{exampleTemp}/build/#{cfg.template}/style/myMainStyle.css", 'utf8')
                    .to.eventually.equal '.anotherStyle{width:2}.myMainStyle{width:1}'

                it "uses `srcMain` to compile 'myMainStyle.css' ONLY", ->
                  expect(fs.existsP "#{exampleTemp}/build/#{cfg.template}/style/morestyles/anotherStyle.css").to.eventually.be.false

            it "lib file exists & has correct content", ->
              When.all [
                expect(fs.existsP mylib).to.eventually.be.true
                expect(fs.readFileP mylib, 'utf8').to.eventually.equal fs.readFileSync mylib, 'utf8' # @todo: equal to what ?
              ]

            describe "`urequire-example` has the correct behavior", ->

              it "exports required modules", ->
                equal buildLib.person.age, 40
                equal buildLib.add(40, 14), 54
                equal buildLib.calc.add(40, 14), 54
                equal buildLib.calc.multiply(40, 3), 120

              it "extends required 'class' modules", ->
                equal buildLib.person.eat('food'), 'ate food'

              describe "it exports:", ->

                it "to root (window / global)", ->
                  equal buildLib, urequireExample
                  equal buildLib, uEx

                it "adds noConflict(), that reclaims overwritten globals", ->
                  equal buildLib.noConflict(), buildLib
                  equal urequireExample, global_urequireExample
                  equal uEx, global_uEx

  describe "`BundleBuilder.buildBundle` rejects failures gracefully:", ->
    failingConfig =
      template: 'combined'
      dstPath: "#{exampleTemp}/build/combinedFailing/urequire-example"
#      debugLevel: 100
#      continue: true

    buildResult = null
    buildError = null

    before ->
      pFile = "#{exampleTemp}/source/code/models/Person.ls"
      pText = fs.readFileSync pFile, encoding: 'utf-8'
      fs.writeFileSync pFile, pText + '\n          a' , encoding: 'utf8'

      afterBuildResults = []

      bb = new urequire.BundleBuilder [failingConfig, defaultConfig]
      bbP = bb.buildBundle()

      bbP.then (res)->
        buildResult = res
        afterBuildResults.push "then1": res

      bbP.then (res)-> afterBuildResults.push "then2": res

      bbP.catch (err)-> afterBuildResults.push "catch1": buildError = err
      bbP.catch (err)-> afterBuildResults.push "catch2": buildError = err

    it "bb.buildBundle().then never called", ->
      equal buildResult, null

    it "bb.buildBundle().catch called with Error", ->
      tru buildError instanceof UError

    describe "afterBuild tasks:", ->
      it "done() tasks are called once each, in serial order, followed by .catch tasks.", ->
        deepEqual afterBuildResults, [
          {'done0': buildError}
          {'done1' : buildError}
          {'done2' : [buildError, bb]}
          {'done3' : [buildError, bb]}
          {'catch1': buildError}
          {'catch2': buildError}
        ]