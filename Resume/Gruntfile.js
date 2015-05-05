module.exports = function (grunt) {

    grunt.initConfig({
        clean: ["Content/lib"],
        "bower-install-simple": {
            options: {
                color: true
            },
            "prod": {
                options: {
                    production: true
                }
            }
        },
        wget: {
            basic: {
                files: {
                    "bin/wget.exe": "https://eternallybored.org/misc/wget/wget.exe"
                }
            },
        }
    });

    grunt.loadNpmTasks("grunt-contrib-clean");

    grunt.loadNpmTasks("grunt-bower-install-simple");

    grunt.loadNpmTasks("grunt-wget");

    grunt.registerTask("bower-install", ["clean", "bower-install-simple"]);
};