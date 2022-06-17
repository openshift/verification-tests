Feature: some collection operations verification

  Scenario: substructs
    Given the expression should be true> cb.h1 = {metadata:{labels:{labelname: nil}}}
    And   the expression should be true> cb.h2 = {metadata:{labels:nil}}
    Then  the expression should be true> ! substruct?(cb.h2, cb.h1)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, null_deletes_key: true)
    And   the expression should be true> ! substruct?(cb.h1, cb.h2, vague_nulls: true)
    And   the expression should be true> ! substruct?(cb.h1, cb.h2, null_deletes_key: true)
    And   the expression should be true> substruct?(cb.h1, cb.h2, null_deletes_key: true, vague_nulls: true)

    Given the expression should be true> cb.h1 = {metadata:{labels:{labelname: nil}}}
    And   the expression should be true> cb.h2 = {metadata:{labels:{}}}
    Then  the expression should be true> substruct?(cb.h2, cb.h1)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, null_deletes_key: true)

    Given the expression should be true> cb.h1 = {metadata:{labels:{labelname: nil}}}
    And   the expression should be true> cb.h2 = {metadata:{labels:{labelname: nil}}}
    Then  the expression should be true> substruct?(cb.h2, cb.h1)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, null_deletes_key: true)

    Given the expression should be true> cb.h1 = {metadata:{labels:{labelname: "gah"}}}
    And   the expression should be true> cb.h2 = {metadata:{labels:{labelname: nil}}}
    Then  the expression should be true> ! substruct?(cb.h2, cb.h1)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, null_deletes_key: true)

    Given the expression should be true> cb.h1 = {metadata:{labels:{labelname: {}}}}
    And   the expression should be true> cb.h2 = {metadata:{labels:{labelname: nil}}}
    Then  the expression should be true> ! substruct?(cb.h2, cb.h1)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, null_deletes_key: true)

    Given the expression should be true> cb.h1 = {metadata: 123}
    And   the expression should be true> cb.h2 = {metadata: 123, d: nil}
    Then  the expression should be true> ! substruct?(cb.h2, cb.h1)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, null_deletes_key: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true, null_deletes_key: true)

    ## Arrays
    Given the expression should be true> cb.h1 = {metadata:{labels:{labelname: []}}}
    And   the expression should be true> cb.h2 = {metadata:{labels:{labelname: nil}}}
    Then  the expression should be true> ! substruct?(cb.h2, cb.h1)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true, exact_arrays: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, null_deletes_key: true)

    Given the expression should be true> cb.h1 = {metadata:{labels:{labelname: []}}}
    And   the expression should be true> cb.h2 = {metadata:{labels:{labelname: []}}}
    Then  the expression should be true> substruct?(cb.h2, cb.h1)
    And   the expression should be true> substruct?(cb.h2, cb.h1, exact_arrays: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true, exact_arrays: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, null_deletes_key: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, null_deletes_key: true, exact_arrays: true)

    Given the expression should be true> cb.h1 = {metadata:{labels: [{labelname: []}, 123, [], ["asd"]]}}
    And   the expression should be true> cb.h2 = {metadata:{labels: [{labelname: []}, 123, [], ["asd"]]}}
    Then  the expression should be true> substruct?(cb.h2, cb.h1)
    And   the expression should be true> substruct?(cb.h2, cb.h1, exact_arrays: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true, exact_arrays: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, null_deletes_key: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, null_deletes_key: true, exact_arrays: true)

    Given the expression should be true> cb.h1 = {metadata:{labels: [{labelname: []}, 123, ["asd"]]}}
    And   the expression should be true> cb.h2 = {metadata:{labels: [{labelname: []}, 123, [], ["asd"]]}}
    Then  the expression should be true> ! substruct?(cb.h2, cb.h1)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, exact_arrays: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, vague_nulls: true, exact_arrays: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, null_deletes_key: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, null_deletes_key: true, exact_arrays: true)

    Given the expression should be true> cb.h1 = {metadata:{labels: [{labelname: []}, [], 123, ["asd"]]}}
    And   the expression should be true> cb.h2 = {metadata:{labels: [{labelname: []}, 123, [], ["asd"]]}}
    Then  the expression should be true> substruct?(cb.h2, cb.h1)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, exact_arrays: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, vague_nulls: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, vague_nulls: true, exact_arrays: true)
    And   the expression should be true> substruct?(cb.h2, cb.h1, null_deletes_key: true)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, null_deletes_key: true, exact_arrays: true)

    Given the expression should be true> cb.h1 = {metadata:{labels: [{labelname: [], asd: 5}, [], 123, ["asd"]]}}
    And   the expression should be true> cb.h2 = {metadata:{labels: [{labelname: []}, [], 123, ["asd"]]}}
    Then  the expression should be true> substruct?(cb.h2, cb.h1)
    And   the expression should be true> ! substruct?(cb.h2, cb.h1, exact_arrays: true)

    # warning: order edge case false negative
    # this is for demonstrative purposes, do not rely on this behavior
    Given the expression should be true> cb.h1 = {metadata:{labels: [[11, 12], [12]]}}
    And   the expression should be true> cb.h2 = {metadata:{labels: [[12], [11, 12]]}}
    Then  the expression should be true> ! substruct?(cb.h2, cb.h1, exact_arrays: false)
    And   the expression should be true> substruct?(cb.h1, cb.h2, exact_arrays: false)
