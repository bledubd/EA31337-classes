//+------------------------------------------------------------------+
//|                                                EA31337 framework |
//|                       Copyright 2016-2020, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/*
 * This file is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

// Includes.
#include "../Indicator.mqh"

#ifndef __MQL4__
// Defines global functions (for MQL4 backward compability).
double iFractals(string _symbol, int _tf, int _mode, int _shift) {
  return Indi_Fractals::iFractals(_symbol, (ENUM_TIMEFRAMES)_tf, (ENUM_LO_UP_LINE)_mode, _shift);
}
#endif

// Structs.
struct FractalsParams : IndicatorParams {
  // Struct constructors.
  void FractalsParams(ENUM_TIMEFRAMES _tf = PERIOD_CURRENT) {
    itype = INDI_FRACTALS;
    max_modes = 2;
    SetDataValueType(TYPE_DOUBLE);
    tf = _tf;
    tfi = Chart::TfToIndex(_tf);
  };
  void FractalsParams(FractalsParams &_params, ENUM_TIMEFRAMES _tf = PERIOD_CURRENT) {
    this = _params;
    tf = _tf;
  };
};

/**
 * Implements the Fractals indicator.
 */
class Indi_Fractals : public Indicator {
 protected:
  FractalsParams params;

 public:
  /**
   * Class constructor.
   */
  Indi_Fractals(IndicatorParams &_p) : Indicator((IndicatorParams)_p) {}
  Indi_Fractals(ENUM_TIMEFRAMES _tf = PERIOD_CURRENT) : Indicator(INDI_FRACTALS, _tf) {}

  /**
   * Returns the indicator value.
   *
   * @docs
   * - https://docs.mql4.com/indicators/ifractals
   * - https://www.mql5.com/en/docs/indicators/ifractals
   */
  static double iFractals(string _symbol, ENUM_TIMEFRAMES _tf,
                          ENUM_LO_UP_LINE _mode,  // (MT4 _mode): 1 - MODE_UPPER, 2 - MODE_LOWER
                          int _shift = 0,         // (MT5 _mode): 0 - UPPER_LINE, 1 - LOWER_LINE
                          Indicator *_obj = NULL) {
#ifdef __MQL4__
    return ::iFractals(_symbol, _tf, _mode, _shift);
#else  // __MQL5__
    int _handle = Object::IsValid(_obj) ? _obj.GetState().GetHandle() : NULL;
    double _res[];
    ResetLastError();
    if (_handle == NULL || _handle == INVALID_HANDLE) {
      if ((_handle = ::iFractals(_symbol, _tf)) == INVALID_HANDLE) {
        SetUserError(ERR_USER_INVALID_HANDLE);
        return EMPTY_VALUE;
      } else if (Object::IsValid(_obj)) {
        _obj.SetHandle(_handle);
      }
    }
    int _bars_calc = BarsCalculated(_handle);
    if (GetLastError() > 0) {
      return EMPTY_VALUE;
    } else if (_bars_calc <= 2) {
      SetUserError(ERR_USER_INVALID_BUFF_NUM);
      return EMPTY_VALUE;
    }
    if (CopyBuffer(_handle, _mode, _shift, 1, _res) < 0) {
      return EMPTY_VALUE;
    }
    return _res[0];
#endif
  }

  /**
   * Returns the indicator's value.
   */
  double GetValue(ENUM_LO_UP_LINE _mode, int _shift = 0) {
    ResetLastError();
    istate.handle = istate.is_changed ? INVALID_HANDLE : istate.handle;
    double _value = Indi_Fractals::iFractals(GetSymbol(), GetTf(), _mode, _shift, GetPointer(this));
    istate.is_ready = _LastError == ERR_NO_ERROR;
    istate.is_changed = false;
    return _value;
  }

  /**
   * Returns the indicator's struct value.
   */
  IndicatorDataEntry GetEntry(int _shift = 0) {
    long _bar_time = GetBarTime(_shift);
    unsigned int _position;
    IndicatorDataEntry _entry;
    if (idata.KeyExists(_bar_time, _position)) {
      _entry = idata.GetByPos(_position);
    } else {
      _entry.timestamp = GetBarTime(_shift);
      _entry.value.SetValue(params.idvtype, GetValue(LINE_UPPER, _shift), 0);
      _entry.value.SetValue(params.idvtype, GetValue(LINE_LOWER, _shift), 1);
      double _wrong_value = (double)NULL;
      ;
#ifdef __MQL4__
      // In MT4, the empty value for iFractals is 0, not EMPTY_VALUE=DBL_MAX as in MT5.
      // So the wrong value is the opposite.
      _wrong_value = EMPTY_VALUE;
#endif
      _entry.SetFlag(INDI_ENTRY_FLAG_IS_VALID, !_entry.value.HasValue(params.idvtype, _wrong_value));
      if (_entry.IsValid()) idata.Add(_entry, _bar_time);
    }
    return _entry;
  }

  /**
   * Returns the indicator's entry value.
   */
  MqlParam GetEntryValue(int _shift = 0, int _mode = 0) {
    MqlParam _param = {TYPE_DOUBLE};
#ifdef __MQL4__
    // Adjusting index, as in MT4, the line identifiers starts from 1, not 0.
    _mode = _mode > 0 ? _mode - 1 : _mode;
#endif
    _param.double_value = GetEntry(_shift).value.GetValueDbl(params.idvtype, _mode);
    return _param;
  }

  /* Printer methods */

  /**
   * Returns the indicator's value in plain format.
   */
  string ToString(int _shift = 0) { return GetEntry(_shift).value.ToCSV(params.idvtype); }
};
