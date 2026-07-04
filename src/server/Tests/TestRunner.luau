--!strict
-- Minimal assert-based test harness (no external deps). Each sibling module
-- returns { name: string, tests: { [testName]: () -> () } }. Failures throw.
-- run() executes everything and returns (summaryString, allPassed).

local TestRunner = {}

function TestRunner.run(): (string, boolean)
	local lines: { string } = {}
	local passed, failed = 0, 0

	for _, child in script.Parent:GetChildren() do
		if child:IsA("ModuleScript") and child ~= script then
			local suite = require(child) :: any
			for testName, fn in suite.tests do
				local ok, err = pcall(fn)
				if ok then
					passed += 1
					table.insert(lines, ("PASS %s / %s"):format(suite.name, testName))
				else
					failed += 1
					table.insert(lines, ("FAIL %s / %s — %s"):format(suite.name, testName, tostring(err)))
				end
			end
		end
	end

	table.sort(lines)
	table.insert(lines, ("— %d passed, %d failed"):format(passed, failed))
	return table.concat(lines, "\n"), failed == 0
end

return TestRunner
