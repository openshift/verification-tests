# How to Create a Prow job to run CucuShift testing

Please follow this step by step guide to create a new Prow job to run cucushift testing. This document uses the `@aws-ipi` as an example to demonstrate the workflow and assumes you have properly configured your `verification-tests` and `cucushift` repositories.

[[_TOC_]]

## Create a Test Run Query

1. Go to OSE project in Polarion, select `Workitems`, in the search box create your test run query matching your test profile. When constructing the test run query, select only `Critical` and `High` automated test cases.
2. Upon completion of the query, click the `Convert Query to Text`. See the example of *query_aws_ipi_tests.json*.
3. Copy your query and create a `$version/query_$profile_tests.json`, add a PR in this repo and ask qe-productivity for review.

The team should review the test query succesfully matches the profile and merge it.

## Mapping Test Query to CucuShift

Once your query is suffcient for your test profile, you will have to map your selected test cases to cucushift by using tags. Say we are going to add our tests to an AWS IPI cluster for version 4.9, we have to create tags `@aws-ipi` and `@4.9` in order for cucushift to run all test cases by `cucumber --tags @aws-ipi and @4.9`.

The following commands will retrieve all test case ids and add the tag `@aws-ipi` and `@4.9` to all test scearios under `verfication-tests` and `cucushift`

```bash
cd verficiation-tests
# x.y are versions, e.g, 4.9
QUERY_FILE="../path-to-folder/ci-profiles/prow/x.y/query_aws_ipi_tests.json"
TAGS="@aws-ipi,@4.9"
tools/case_id_splitter.rb add-tags --tags ${TAGS} --ids $(tools/polarshift.rb query-cases -f ${QUERY_FILE} | grep -o -E 'OCP-[0-9]+' | tr '\n' ',')
```

Upon completion of the steps, create a pull request in  `verfication-tests` and `cucushift` respectively. Add clear and consistent summary to your PR and ask qe-productivity for review.

## Create a Job in Prow

Once your test case selection is solid, you are ready to create a new job. Fork https://github.com/openshift/release.git and create your own branch. We have job and steps created that you can use as a reference:

- [e2e-cucushift-aws-ipi](https://steps.ci.openshift.org/job?org=openshift&repo=release&branch=master&test=e2e-cucushift-aws-ipi&variant=nightly-4.9)

- [cucushift-pre](https://steps.ci.openshift.org/reference/cucushift-pre): used to prepare your cluster before running CucuShift tests. You should reuse this step as a pre step in your workflow
- [cucushift-aws-ipi](https://steps.ci.openshift.org/reference/cucushift-aws-ipi): Run all `@aws-ipi` test cases in Prow, you should follow this step and create your own step to run on another profile.

Follow the same style and convention to create your steps for the new workflow you are going to add.

Refer to [OpenShift CI Docs](https://docs.ci.openshift.org/docs/architecture/step-registry/#workflow) for additional information.

## Test Your Changes Locally

Upon completion of your job, run `make update` under the `release` repository to validate your changes.

## Create a Pull Request

Create a PR using your work branch, if your PR is a work-in-progress, add a `[WIP]` in the summary. This indicates you will continue to work on your PR and your testing and do not require an immediate review.

## Continously Testing your Pull Request

The Github bot and ci-operator automation will run all tests necessary to validate your pull request. You must have all the tests passed before moving to next steps. In order to get all your tests pass, you are responsible for engagging the test owner for troubleshooting these tests. You and the test owner together should fix all the failed test scenarios. If some tests are never fixed, consider using `@prow_unstable` or `@flaky` tag in the test scenarios to skip them.

## Getting Your Pull Request Merged

Once you have all your tests passed, the github bot will add an `approved` label to your PR. Remove the `[WIP]` from the summary and ask DPTP for review.

Upon being merged, your job will be created

