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
            },
            "dev": {
                options: {
                    production: false
                }
            }
        }
    });

    grunt.loadNpmTasks("grunt-contrib-clean");

    grunt.loadNpmTasks("grunt-bower-install-simple");

    grunt.registerTask("bower-install", ["clean", "bower-install-simple"]);
};