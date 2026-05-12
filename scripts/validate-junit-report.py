import os
import xml.etree.ElementTree as ET
from pathlib import Path


def get_required_env(name):
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


scenario = get_required_env("SCENARIO")
exit_code = int(get_required_env("EXIT_CODE"))
junit_xml = Path(get_required_env("JUNIT_XML"))
summary_label = get_required_env("SUMMARY_LABEL")

if not junit_xml.exists():
    raise SystemExit(f"JUnit XML not found: {junit_xml}")
if junit_xml.stat().st_size == 0:
    raise SystemExit(f"JUnit XML is empty: {junit_xml}")

root = ET.parse(junit_xml).getroot()
if root.tag != "testsuites":
    raise SystemExit(f"Unexpected root element: {root.tag}")

suites = root.findall("testsuite")
cases = root.findall(".//testcase")
failures = root.findall(".//failure")
errors = root.findall(".//error")
browser_properties = root.findall(".//testsuite/properties/property[@name='browser']")

if not suites:
    raise SystemExit("JUnit XML does not contain any testsuite elements")
if not cases:
    raise SystemExit("JUnit XML does not contain any testcase elements")
if not browser_properties:
    raise SystemExit("JUnit XML does not include browser properties")

suite_failures = sum(int(suite.attrib.get("failures", "0")) for suite in suites)
suite_errors = sum(int(suite.attrib.get("errors", "0")) for suite in suites)
total_problems = suite_failures + suite_errors

if scenario == "pass":
    if exit_code != 0:
        raise SystemExit(f"Expected a zero exit code for a passing run, got {exit_code}")
    if total_problems != 0:
        raise SystemExit(f"Expected no failures/errors for a passing run, got {total_problems}")
    if failures or errors:
        raise SystemExit("Expected no failure/error elements for a passing run")
else:
    if exit_code == 0:
        raise SystemExit("Expected a non-zero exit code for a failing run")
    if total_problems == 0:
        raise SystemExit("Expected at least one failure/error in the JUnit XML for a failing run")
    if not failures and not errors:
        raise SystemExit("Expected failure or error elements in the failing JUnit XML")

summary_text = (
    f"### {summary_label} ({scenario})\n"
    f"- XML: `{junit_xml}`\n"
    f"- Exit code: `{exit_code}`\n"
    f"- Testsuites: `{len(suites)}`\n"
    f"- Testcases: `{len(cases)}`\n"
    f"- Failures: `{suite_failures}`\n"
    f"- Errors: `{suite_errors}`\n\n"
)

summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
if summary_path:
    with open(summary_path, "a", encoding="utf-8") as summary:
        summary.write(summary_text)
else:
    print("GITHUB_STEP_SUMMARY is not set; writing JUnit validation summary to stdout.")
    print(summary_text, end="")
