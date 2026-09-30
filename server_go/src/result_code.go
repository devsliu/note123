package main

type ResultCode struct {
	Value   int
	Message string
}

func (rc ResultCode) with(message string) ResultCode {
	return ResultCode{rc.Value, message}
}

func ResultCodeError(rc *ResultCode, defaultRC ResultCode, err error) ResultCode {
	if err != nil {
		if rc != nil {
			return *rc
		}
		return defaultRC
	}
	return ResultSuccess
}

var (
	ResultSuccess             = ResultCode{200, "OK"}
	ResultErrorRecordConflict = ResultCode{531, "record conflict"}
	ResultErrorDatabase       = ResultCode{532, "database error"}
	ResultErrorRecordNotFound = ResultCode{533, "record not found"}
	ResultErrorParams         = ResultCode{534, "invalid parameter"}
	ResultErrorFileSave       = ResultCode{535, "file save error"}
	ResultErrorFileNotFound   = ResultCode{536, "file not found"}

	ResultErrorUserPasswordError = ResultCode{561, "invalid username or password"}
)
