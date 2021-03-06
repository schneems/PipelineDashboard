.DEFAULT_GOAL := help

help:
	@echo 'Please read the documentation in "https://github.com/DashboardHub/PipelineDashboard"'

guard-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* is not set"; \
		exit 1; \
	fi

# ALIAS
api: api.run

ui: ui.run

install.local: alexa.install api.install ui.install
	(cd api; ./node_modules/serverless/bin/serverless dynamodb install --stage dev)

install: pipeline.version.startBuild pipeline.version.prod.startBuild alexa.install api.install ui.install pipeline.version.finishBuild pipeline.version.prod.finishBuild

install.test: pipeline.version.test.startBuild pipeline.version.prod.test.startBuild alexa.install api.install ui.install pipeline.version.test.finishBuild pipeline.version.prod.test.finishBuild

deploy: pipeline.version.startDeploy pipeline.version.prod.startDeploy alexa.deploy api.deploy ui.deploy pipeline.version.finishDeploy pipeline.version.prod.finishDeploy

deploy.test: pipeline.version.test.startDeploy pipeline.version.prod.test.startDeploy alexa.deploy api.deploy.test ui.deploy.test pipeline.version.test.finishDeploy pipeline.version.prod.test.finishDeploy

# ALEXA
alexa.install:
	(cd alexa; rm -fr node_modules || echo "Nothing to delete")
	(cd alexa; npm install)

alexa.deploy:
	(cd alexa; ./node_modules/serverless/bin/serverless deploy -v)

alexa.remove:
	(cd alexa; ./node_modules/serverless/bin/serverless remove -v)

# API
api.clean:
	(cd api; git checkout ./config.json)

api.install:
	(cd api; rm -fr node_modules || echo "Nothing to delete")
	(cd api; npm install)

api.env: guard-AUTH0_CLIENT_ID guard-AUTH0_CLIENT_SECRET api.clean
	(cd api; sed -i 's|{{ AUTH0_CLIENT_ID }}|${AUTH0_CLIENT_ID}|g' ./config.json)
	(cd api; sed -i 's|{{ AUTH0_CLIENT_SECRET }}|${AUTH0_CLIENT_SECRET}|g' ./config.json)
	(cd api; sed -i 's|pipelinedashboard-environments|pipelinedashboard-environments-prod|g' ./config.json)
	(cd api; sed -i 's|pipelinedashboard-deployed|pipelinedashboard-deployed-prod|g' ./config.json)
	(cd api; sed -i 's|pipelinedashboard-pinged|pipelinedashboard-pinged-prod|g' ./config.json)

api.env.test: guard-AUTH0_CLIENT_ID_TEST guard-AUTH0_CLIENT_SECRET_TEST api.clean
	(cd api; sed -i 's|{{ AUTH0_CLIENT_ID }}|${AUTH0_CLIENT_ID_TEST}|g' ./config.json)
	(cd api; sed -i 's|{{ AUTH0_CLIENT_SECRET }}|${AUTH0_CLIENT_SECRET_TEST}|g' ./config.json)
	(cd api; sed -i 's|pipelinedashboard-environments|pipelinedashboard-environments-test|g' ./config.json)
	(cd api; sed -i 's|pipelinedashboard-deployed|pipelinedashboard-deployed-test|g' ./config.json)
	(cd api; sed -i 's|pipelinedashboard-pinged|pipelinedashboard-pinged-test|g' ./config.json)

api.run: api.env.test
	(cd api; ./node_modules/serverless/bin/serverless offline start --stage dev)

api.deploy: api.env
	(cd api; mv dashboardhub.prod.pem dashboardhub.pem)
	(cd api; ./node_modules/serverless/bin/serverless deploy -v --stage production)

api.deploy.test: api.env.test
	(cd api; mv dashboardhub.test.pem dashboardhub.pem)
	(cd api; ./node_modules/serverless/bin/serverless deploy -v --stage test)

api.remove:
	(cd api; ./node_modules/serverless/bin/serverless remove -v --stage production)

api.remove.test:
	(cd api; ./node_modules/serverless/bin/serverless remove -v --stage test)

# UI
ui.install:
	(cd web; rm -fr node_modules || echo "Nothing to delete")
	(cd web; npm install)

ui.run:
	(cd web; ./node_modules/@angular/cli/bin/ng serve)

ui.deploy: ui.version ui.build ui.sync

ui.deploy.test: ui.version ui.build.test ui.sync.test

ui.build:
	(cd web; ./node_modules/@angular/cli/bin/ng build --prod --aot --env=prod)

ui.build.test:
	(cd web; ./node_modules/@angular/cli/bin/ng build --prod --aot --env=test)

ui.version:
	(cd web/src/environments; sed -i 's/x\.x\.x/0.8.${TRAVIS_BUILD_NUMBER}-ALPHA/g' environment.prod.ts)
	(cd web/src/environments; sed -i 's/x\.x\.x/0.8.${TRAVIS_BUILD_NUMBER}-ALPHA/g' environment.test.ts)

ui.sync: guard-AWS_CLOUDFRONT_ID
	(cd web; aws s3 sync dist s3://pipeline.dashboardhub.io --delete --region eu-west-2)
	aws cloudfront create-invalidation --distribution-id ${AWS_CLOUDFRONT_ID} --paths /\*

ui.sync.test:
	(cd web; aws s3 sync dist s3://pipeline-test.dashboardhub.io --delete --region eu-west-2)

# DASHBOARDHUB PIPELINE TEST

pipeline.version.startBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/284d3180-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN}/startBuild

pipeline.version.finishBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/284d3180-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN}/finishBuild

pipeline.version.failBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/284d3180-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN}/failBuild

pipeline.version.startDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/284d3180-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN}/startDeploy

pipeline.version.finishDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/284d3180-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN}/finishDeploy

pipeline.version.failDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/284d3180-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN}/failDeploy

pipeline.version.test.startBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/b4d0b870-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN_TEST}/startBuild

pipeline.version.test.finishBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/b4d0b870-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN_TEST}/finishBuild

pipeline.version.test.failBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/b4d0b870-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN_TEST}/failBuild

pipeline.version.test.startDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/b4d0b870-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN_TEST}/startDeploy

pipeline.version.test.finishDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/b4d0b870-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN_TEST}/finishDeploy

pipeline.version.test.failDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://dj2hjusr1g.execute-api.eu-west-2.amazonaws.com/test/environments/b4d0b870-c9e9-11e7-aeea-eb4cced29ed2/deployed/${DH_TOKEN_TEST}/failDeploy

# DASHBOARDHUB PIPELINE PROD

pipeline.version.prod.startBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1fd1da50-ca3a-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD}/startBuild

pipeline.version.prod.finishBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1fd1da50-ca3a-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD}/finishBuild

pipeline.version.prod.failBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1fd1da50-ca3a-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD}/failBuild

pipeline.version.prod.startDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1fd1da50-ca3a-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD}/startDeploy

pipeline.version.prod.finishDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1fd1da50-ca3a-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD}/finishDeploy

pipeline.version.prod.failDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1fd1da50-ca3a-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD}/failDeploy

pipeline.version.prod.test.startBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1012de50-ca3c-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD_TEST}/startBuild

pipeline.version.prod.test.finishBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1012de50-ca3c-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD_TEST}/finishBuild

pipeline.version.prod.test.failBuild:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1012de50-ca3c-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD_TEST}/failBuild

pipeline.version.prod.test.startDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1012de50-ca3c-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD_TEST}/startDeploy

pipeline.version.prod.test.finishDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1012de50-ca3c-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD_TEST}/finishDeploy

pipeline.version.prod.test.failDeploy:
	curl -XPOST -H "Content-Type: application/json"  -d '{"release":"0.8.${TRAVIS_BUILD_NUMBER}"}' https://wxhly2j3oc.execute-api.eu-west-2.amazonaws.com/production/environments/1012de50-ca3c-11e7-8e89-ddd24d528194/deployed/${DH_TOKEN_PROD_TEST}/failDeploy
