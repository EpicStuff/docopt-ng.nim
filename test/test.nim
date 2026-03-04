import std/[algorithm, json, os, strutils, tables, options]

include docopt


proc value_to_json(v: Value): JsonNode =
  case v.kind
    of vkNone:
      newJNull()
    of vkBool:
      %v.to_bool
    of vkInt:
      %v.len
    of vkStr:
      %($v)
    of vkList:
      %(@v)

proc output_to_json(output: Table[string, Value]): JsonNode =
  result = newJObject()
  for k, v in output.pairs:
    result[k] = value_to_json(v)


proc test(doc, args, expected_s: string): bool =
  var expected_json = parse_json(expected_s)
  var error = ""
  try:
    try:
      var output = docopt(doc, args.split_whitespace(), quit = false)
      var expected = init_table[string, Value]()
      for k, v in expected_json:
        expected[k] = case v.kind
          of JNull: val()
          of JString: val(v.str)
          of JInt: val(int(v.num))
          of JBool: val(v.bval)
          of JArray: val(v.elems.map_it(string, it.str))
          else: val()
      error = "!= " & $output_to_json(output)
      assert expected == output
    except DocoptExit:
      error = "DocoptExit on valid input"
      assert expected_json.kind == JString and
        expected_json.str == "user-error"
    return true
  except AssertionDefect:
    echo "-------- TEST NOT PASSED --------"
    echo doc
    echo "$ prog ", args, " "
    echo expected_s
    echo error
    echo "---------------------------------"
    return false

proc docopt_test_files(): seq[string] =
  result = @[]
  for path in walk_files("test/*.docopt"):
    result.add(path)
  result.sort(system.cmp[string])

var total, passed = 0
for tests_path in docopt_test_files():
  var args, expected: options.Option[string]
  var doc: string
  var in_doc = false
  let tests = readFile(tests_path)
  for each_line in (tests & "\n\n").split_lines():
    var line = each_line.partition("#").left
    if not in_doc and line.starts_with("r\"\"\""):
      in_doc = true
      doc = ""
      line = line.substr(4)
    if in_doc:
      doc &= line
      if line.ends_with("\"\"\""):
        doc = doc[0 .. doc.len-4]
        in_doc = false
      doc &= "\n"
    elif line.starts_with("$ "):
      assert args.is_none and expected.is_none
      let cmd = line.substr(2).split_whitespace()
      args = some(if cmd.len > 1: cmd[1..^1].join(" ") else: "")
    elif line.starts_with("{") or line.starts_with("\""):
      assert args.is_some and expected.is_none
      expected = some(line)
    elif line.len > 0:
      assert expected.is_some
      expected = some(expected.get & "\n" & line)
    if line.len == 0 and args.is_some and expected.is_some:
      total += 1
      if test(doc, args.get, expected.get):
        passed += 1
      stdout.write("\rTests passed: $#/$#\r".format(passed, total))
      args = none(string)
      expected = none(string)

echo()
quit(if passed == total: 0 else: 1)
