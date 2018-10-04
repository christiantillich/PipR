
# Objective

To provide a tool that manages all transformations necessary to prepare a data set for use in some model development framework. PipR also performs an arbitrary number of tests at every step, and creates documentation useful for documentation or spotting inconsistencies/errors. 

# Usage

To use PipR, you start by creating a yaml file (a recipe) that describes the preprocessing you wish to perform. When the recipe is ready, the function `pipe()` takes it and runs each of the transformations specified in that recipe and executes them. Users may also specify checks that they wish to execute after each step of the recipe is completed, and they can also restrict certain checks to only run on certain steps if needed. When `pipe()` finishes executing, it writes the steps and check results out to a log file, which can easily be examined for errors or copied into model documentation. 

A PipR recipe divides into three sections: `configs`, `steps`, and `checks`. Configs specify certain global variables that the script might use - e.g. which functions you're using to read/write, or what the root directory is you're writing to. Steps contains all the different transformations you're applying to the data, as well as parameters to control the read/writing of the finished data. Checks specify the functions you want to run at the end of every step. 

Note that `pipe()` can be called with `run_checks = FALSE` or `run_pipe = FALSE` to turn off checks or steps entirely. Useful when you just want to rebuild the documentation without rebuilding your data sets, or vice-versa. Note too that any config value can be overwritten at a specific step. Similarly, additional checks may be added at the step level. 

## Configs

Global options you can specify that will apply to the whole process. 

reader - The function used to read in data sets. 

writer - The function used to write out data sets. 

local_dir - specifies which directory holds the necessary transform/check definitions. 

s3_dir - specifies the root directory for reading/writing (I probably need to change the name here - PipR can support any read/write function, not just the tools we have for S3)

transform\_files - The name of the file that defines the transform functions. 

check\_files - The name of the file that defines the check functions. 

## Steps

description - Text describing the goal of this step. Fed right into the final log file.  

transform - The name of the function used at this step. This can also be an array with `name:` specifying the function name and each additional argument taking the form `[[name]]: [[value]]`  

type - A code to specify the expected inputs and outputs of this step. The code follows the form `XfX`, where `X` can take values of 0 (left only), 1, or M. The left `X` describes the number of separate files input, and the right describes the number of files that PipR expects to write out. So `type: 1f1` specifies that this transformation takes one data set in, applies the transform function, and writes one data set out. In contrast, `type: 1fM` specifies that this transformation takes 1 data set, applies the transform, and then outputs several data sets as a result. And `type: 0f1` takes no input, but outputs a single data set (e.g. a wrapper around some SQL query). Order matters for both inputs and outputs. For inputs, the data sets will be read sequentially and input as argument 1,2,3, etc. For outputs, your transform function should return a list with the first element of that list being the first data set to be written to the first path specified, and so on.   

in - The name/path, or list of name/paths, that PipR will read in as input to the transform function.   

out - The name/path, or list of name/paths, that PipR will write out after the transform is applied. 

checks - A list of functions to run as checks, exclusively to this step. This can also be an array with `name:` specifying the function name and each additional argument taking the form `[[name]]: [[value]]`

## Checks

This section is a single list. Each element here is a single function that you'll run against the output data set. Each element may also be an array with `name:` specifying the function name and each additional argument taking the form `[[name]]: [[value]]`

# An Example Recipe File

This comes from an actual project, with some specifics changed. 

    configs:
      reader: s3read
      writer: s3store
      local_dir: path/to/working/directory/preprocessing
      s3_dir: path/to/data/set/storage
      transform_files: transforms.R
      check_files: checks.R
    steps:
      - 
        description: "Pull raw data"
        transform: pull_raw_and_diagnostic
        type: '0f1'
        out: raw
        checks: 
          - function: {name: count_uniques, id_name: ca_id}
          - function: {name: date_range, date_field: ca_created_time}
      -
        description: "Create diagnostic set"
        transform: create_diagnostic_set
        type: '1f1'
        in: raw
        out: diagnostic
        checks: 
          - function: {name: count_uniques, id_name: ca_id}
          - function: {name: date_range, date_field: ca_created_time}
      -
        description: "Remove the table headers from column names"
        transform: scrub_headers
        type: '1f1'
        in: raw
        out: clean_heads
      -
        description: "Remove any loans where type == bad"
        transform: remove_bad_types
        type: '1f1'
        in: clean_heads
        out: good_only
      -
        description: "Put performance measures into a separate set"
        transform: separate_performance_measures
        type: '1fM'
        in: good_only
        out:
          - performance_measures
          - explanatory_variables
      - 
        description: "Set aside non-new loans in a separate set"
        transform: separate_refinances
        type: '1fM'
        in: explanatory_variables
        out: 
          - new_loans
          - refinances_and_existing
      -
        description: "Create the small set with the reduced variables."
        transform: make_small
        type: '1f1'
        in: new_loans
        out: small_set
      -
        description: "Create training and testing sets for the small set."
        transform: training_partitions
        type: '1fM'
        s3_dir: path/to/working/directory
        in: preprocessing/small_set
        out: 
          - analysis/small/testing
          - analysis/small/training
      - 
        description: "Create supplemental base set"
        transform: create_supplemental_set
        type: '0f1'
        out: supplemental_2017
      - 
        description: "Join supplemental set to the new loans set"
        transform: add_supplemental
        type: 'Mf1'
        in:
          - new_loans
          - supplemental_2017
        out: with_supplemental
      -
        description: "Create Temporal Features"
        transform: time_features
        type: '1f1'
        in: with_supplemental
        out: with_time_features
      -
        description: "Create Application Features"
        transform: application_features
        type: '1f1'
        in: with_time_features
        out: with_application_features
      -
        description: "Create Customer Features"
        transform: customer_features
        type: '1f1'
        in: with_application_features
        out: with_customer_features
      -
        description: "Create Lead Features"
        transform: lead_features
        type: '1f1'
        in: with_customer_features
        out: with_lead_features
      -
        description: "Create Loan Features"
        transform: loan_features
        type: '1f1'
        in: with_lead_features
        out: with_loan_features
      -
        description: "Create training and testing sets for the full set."
        transform: training_partitions
        type: '1fM'
        s3_dir: path/to/working/directory
        in: preprocessing/with_loan_features
        out: 
          - analysis/full/testing
          - analysis/full/training
      -
        description: "Create diagnostic set"
        transform: create_diagnostic_set
        type: 'MfM'
        s3_dir: path/to/working/directory/analysis
        in:
          - small/training
          - full/training
        out: 
          - small/diagnostic
          - full/diagnostic
    checks:
      - function: get_dim
      - function: {name: count_uniques, id_name: application_id}
      - function: count_missing_cols
      - function: {name: date_range, date_field: application_created_time}
      - function: column_types
      - function: has_text_nas
