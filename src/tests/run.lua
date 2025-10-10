local tests = {
	"./query.test",
	"./common.test",
	"./path.test",
	"./matchers.test",
	-- add tests here when you write then
}

for _, testPath in tests do
	local runTest = require(testPath)
	assert(type(runTest) == "function")
	runTest()
end
