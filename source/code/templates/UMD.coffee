pathRelative = require('../utils/pathRelative')
#
#  A 'simple' template for a UMD module. Based on https://github.com/umdjs/umd/blob/master/returnExportsGlobal.js
#
#  @param d {Object} with
#   {
#     modulePath: where the module is, within bundle
#     type: 'define' or 'require'
#     dependencies: Array of dependencies, as delcared in the original AMD, (eg 'views/PersonView')
#     nodeDependencies: Array for file-relative dependencies, as required by node (eg '../PersonView')
#     requireDependencies: Array of dependencies `require('dep')`, as found in AMD file (that are not in original dependencies)
#     parameters: Array of parameter names, as declared on the original AMD.
#     rootExports: the name of the root variable to export on the browser side (or false/absent)
#     factoryBody: The actual code that returns our module (define) or just runs some code having dependencies resolved (require).
#  }
#
#todo: recognise define [], -> or require [], -> and adjust both node & browser UMD accordingly
#todo: make node part really async with timeout
#todo: make unit tests
UMDtemplate = (d)->
  """
  // Generated by uRequire v#{d.version}
  (function (root, factory) {
      "use strict";
      if (typeof exports === 'object') {
          var nodeRequire = require('uRequire').makeNodeRequire('#{d.modulePath}', __dirname, '#{d.webRoot}');
          module.exports = factory(nodeRequire#{
            (", require('#{nDep}')" for nDep in d.nodeDependencies).join('')
          });
      } else if (typeof define === 'function' && define.amd) {

          define(#{
            if d.moduleName
              "'" + d.moduleName +"', "
            else ""
           }['require'#{
                      (", '#{dep}'" for dep in d.dependencies).join('')
                      }#{
                      (", '#{dep}'" for dep in d.requireDependencies).join('')}],#{
              if d.rootExports # Adds browser/root globals if needed
                "function (require#{(', ' + par for par in d.parameters).join('')}) { \n" +
                "    return (root.#{d.rootExports} = factory(require#{
                  (', ' + par for par in d.parameters).join('')
                }));\n});"
              else
                'factory);'
          }
      }
  })(this, function (require#{ (", #{par}" for par in d.parameters).join ''}) {#{d.factoryBody}});
  """


module.exports = UMDtemplate