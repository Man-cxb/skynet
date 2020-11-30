using System;
using NPOI.SS.UserModel;
using NPOI.HSSF.UserModel;
using System.IO;
using System.Data;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Diagnostics;
using System.Text;
using NPOI.HSSF.Util;

public class CfgExportor
{
    private static int Rgb2Int(ushort r, ushort g, ushort b)
    {
        return r << 16 | g << 8 | b;
    }
    public enum FieldRule { RULE_ERROR = 0, RULE_COMMON, RULE_SERVER, RULE_CLIENT, RULE_IGNORE, RULE_FINISH, RULE_CONTENT }
    private static Dictionary<int, FieldRule> color_rule = new Dictionary<int, FieldRule>()
        {
            {Rgb2Int(  0, 128,   0), FieldRule.RULE_COMMON},
            {Rgb2Int(255, 204,   0), FieldRule.RULE_SERVER},
            {Rgb2Int(  0, 204, 255), FieldRule.RULE_CLIENT},
            {Rgb2Int(150, 150, 150), FieldRule.RULE_IGNORE},
            {Rgb2Int(  0,  51, 102), FieldRule.RULE_FINISH},
            {Rgb2Int(  0,   0,   0), FieldRule.RULE_CONTENT},
        };
    public FieldRule GetColorRule(int color)
    {
        try
        {
            return color_rule[color];
        }
        catch (Exception _e)
        {
            return FieldRule.RULE_ERROR;
        }
    }
    public FieldRule GetColorRule(byte[] rgb)
    {
        if (rgb.Length < 3)
            return FieldRule.RULE_ERROR;
        return this.GetColorRule(Rgb2Int(rgb[0], rgb[1], rgb[2]));
    }
    struct HeadCol
    {
        public int index;
        public FieldRule rule;
        public string name;
        public string shortName;
    }
    struct RecordCol
    {
        public int index;
        public object val;
        public CellType type;
    }
    private string filename;
    private string exportname;
    private IWorkbook workbook;
    private ISheet sheet;
    private List<HeadCol> header;
    private List<HeadCol> comment;
    private List<Dictionary<string, RecordCol>> records;

    public CfgExportor(string filename)
    {
        this.header = new List<HeadCol>();
        this.comment = new List<HeadCol>();
        this.records = new List<Dictionary<string, RecordCol>>();
        this.filename = filename;
        this.exportname = Path.GetFileNameWithoutExtension(filename);
    }
    private string RemoveBlank(string str)
    {
        return str.Replace(" ", "").Replace("\t", "").Replace("\r", "").Replace("\n", "");
    }
    private bool IsTable(string str)
    {
        str = RemoveBlank(str);
        if (!str.StartsWith("{") || !str.EndsWith("}"))
            return false;
        // 判断是否为json格式
		int num = 0;
        for (int i = 0; i < str.Length; i++)
        {
            char ch = str[i];
            if (ch == '"')
            {
                num++;
            }
            if (num % 2 == 0 && i < str.Length - 1 && str[i + 1] == ':')
            {
                return false;
            }
        }

        return true;
    }
    private string PreprocessTable(string str)
    {
        int lbrace_cnt = Regex.Matches(str, @"{").Count;
        int rbrace_cnt = Regex.Matches(str, @"}").Count;
        if (lbrace_cnt != rbrace_cnt)
        {
            Console.WriteLine("大括号数目不匹配.\r\n" + str);
            throw new Exception("大括号数目不匹配。\r\n" + str);
        }
        str = RemoveBlank(str).Replace(",}", "}");
        if (!str.StartsWith("{") || !str.EndsWith("}"))
        {
            Console.WriteLine("Error!!! lua table必须使用{} <<<\r\n" + str);
            throw new Exception("Error!!! lua table必须使用{} <<<\r\n" + str);
        }
        if (lbrace_cnt == 1)
            return str.Substring(1, str.Length - 2);
        return null;
    }
    private string Table2String(string str)
    {
        string tmp_str = PreprocessTable(str);
        if (tmp_str != null)
            return tmp_str.Replace(",", ";");

        tmp_str = str.Substring(1, str.Length - 2);
        string[] str_arr = Regex.Split(tmp_str, @"},{");
        if (str_arr.Length == 1)
        {
            string s = str_arr[0].Substring(1, str_arr[0].Length - 2).Replace("{", "").Replace("}", "").Replace(",", "#");
            return s;
        }
        else
        {
            string final_s = "";
            foreach (string s in str_arr)
            {
                final_s += s.Replace("{", "").Replace("}", "").Replace(",", "#") + ';';
            }
            return final_s.Substring(0, final_s.Length - 1);
        }
    }
    private string QuoteCsvString(string str)
    {
        if (str.Length == 0)
            return str;

        str = str.Replace("\"", "\"\"");
        if (str.IndexOf(",") > 0)
        {
            str = '"' + str + '"';
        }

        return str;
    }

    private string QuoteStr(string str)
    {
        if (str.Length == 0)
            return "\"\"";
        double res;
        if (double.TryParse(str, out res))
            return str;

        if (str.StartsWith("0x") || str.StartsWith("0X"))
        {
            if (str.Length >= 3 )
            {
                string tmp = str.Substring(2);
                if (double.TryParse(tmp, out res))
                    return str;
            }
        }

        //if (!str.StartsWith("\"") && !str.EndsWith("\""))
        //{
        //    str = str.Replace("\"", "\\\"");
        //}
         
        if (!str.StartsWith("\""))
            str = '"' + str;
        if (!str.EndsWith("\""))
            str = str + '"';
        
        return str;
    }
    private string ConvertArray(string str, bool is_lua)
    {
        string tmp = "";
        string curstr = "";
        bool in_str = false;
        bool next_escape = false;
        for (int i = 0; i < str.Length; i++)
        {
            char ch = str[i];
            if (ch == '"')
            {
                // 只能是转义或某一个元素的最开始及结尾
                if (!next_escape)
                {
                    if (in_str)
                    {
                        if(! (i == str.Length - 1 || str[i+1] == ',' || str[i+1] == '='))
                        {
                            char pre = ' ';
                            if (i > 0)
                                pre = str[i - 1];
                            char last = ' ';
                            if (i < str.Length - 1)
                                last = str[i + 1];
                            Console.WriteLine("Convert array error! {0} {1} {2} {3} {4} {5} {6}", str, i, ch, next_escape, in_str, pre, last);
                            return tmp;
                        }
                        in_str = false;
                    }
                    else
                    {
                        if (!(i == 0 || str[i - 1] == ',' || str[i-1] == '='))
                        {
                            char pre = ' ';
                            if (i > 0)
                                pre = str[i - 1];
                            char last = ' ';
                            if (i < str.Length - 1)
                                last = str[i + 1];
                            Console.WriteLine("Convert array error! {0} {1} {2} {3} {4} {5} {6}", str, i, ch, next_escape, in_str, pre, last);
                            return tmp;
                        }
                        in_str = true;
                    }
                }
                else
                {
                    curstr += ch;
                }
            }
            else if (ch == ',' || ch == '=')
            {
                if (in_str == true)
                    curstr += ch;
                else
                {
                    if (is_lua && !(curstr.StartsWith("\"") && curstr.EndsWith("\"")))
                    {
                        if (ch == '=')
                        {
                            int key;
                            if (int.TryParse(curstr, out key))
                            {
                                tmp += "[" + curstr + "]" + ch;
                            }
                            else
                            {
                                tmp += curstr + ch;
                            }
                        }
                        else
                        {
                            tmp += QuoteStr(curstr) + ch;
                        }
                    }   
                    else
                        tmp += curstr + ch;
                    curstr = "";
                    in_str = false;
                    next_escape = false;
                }
            }
            else
                curstr += ch;
			
            if (ch == '\\')
                next_escape = !next_escape;
            else
                next_escape = false;
            if (i == str.Length - 1)
            {
                if (in_str)
                {
                    Console.WriteLine("Convert array error!! {0} {1} {2} {3} {4}", str, i, ch, next_escape, in_str);
                    return tmp;
                }
                else if (is_lua && !(curstr.Length > 0 && curstr.StartsWith("\"") && curstr.EndsWith("\"")))
                    tmp += QuoteStr(curstr) + ',';
                else
                    tmp += curstr + ',';
            }
        }
        if (tmp.Length < 1)
            return "{}";
        return "{" + tmp.Substring(0, tmp.Length - 1) + "}";
    }
    private string ConvertLuaTable(string str)
    {
        string tmp_str = PreprocessTable(str);
        //Console.WriteLine("ConvertLuaTable str=" + str + " tmp_str = "+ tmp_str);
        if (tmp_str != null)
            return ConvertArray(tmp_str, true);

        tmp_str = str.Substring(1, str.Length - 2);
        string[] str_arr = Regex.Split(tmp_str, @"},{");
        if (str_arr.Length == 1)
        {
            string s = str_arr[0].Substring(1, str_arr[0].Length - 2).Replace("{", "").Replace("}", "");
            return "{" + ConvertArray(s, true) + "}";
        }
        else
        {
            string final_s = "";
            foreach (string s in str_arr)
            {
                string tmp = s.Replace("{", "").Replace("}", "");
                final_s += ConvertArray(tmp, true) + ',';
            }
            return "{" + final_s.Substring(0, final_s.Length - 1) + "}";
        }
    }
    private string Float2String(double val)
    {
        double diff = val - (int)val;
        int tmp = (int)(diff * 1000);
        if (tmp > 0)
            return val.ToString();
        else
            return ((int)val).ToString();
    }
    private bool IsSkipRow(IRow row)
    {
        if (row == null)
            return true;
        ICell cell = row.GetCell(0);
        CellType type;
        object obj = GetValueType(cell, out type);
        if (obj == null)
            return true;
        string str = obj.ToString();
        if (str == "" || str.StartsWith("//"))
            return true;
        IColor color = cell.CellStyle.FillForegroundColorColor;
        if (color == null)
            return false;
        FieldRule rule = GetColorRule(color.RGB);
        if (rule == FieldRule.RULE_ERROR)
            return true;
        return false;
    }
    private bool IsFinishRow(IRow row)
    {
        if (row == null)
            return false;
        ICell cell = row.GetCell(0);
        if (cell == null)
            return false;
        IColor color = cell.CellStyle.FillForegroundColorColor;
        // color == null 未设置颜色，默认白色
        if (color == null)
            return false;
        return GetColorRule(color.RGB) == FieldRule.RULE_FINISH;
    }
    private void PrintColor()
    {
        for (int i = sheet.FirstRowNum; i < sheet.LastRowNum; i++)
        {
            IRow row = sheet.GetRow(i);
            if (row == null)
                continue;
            for (int j = row.FirstCellNum; j < row.LastCellNum; ++j)
            {
                ICell cell = row.GetCell(j);
                if (cell == null)
                    continue;
                Console.Write(i + "," + j + ":");
                HSSFColor color = (HSSFColor)cell.CellStyle.FillForegroundColorColor;
                Console.Write("(" + color.RGB[0] + "," + color.RGB[1] + "," + color.RGB[2] + ") ");
            }
            Console.WriteLine();
        }
    }
    public bool LoadFile()
    {
        using (FileStream fs = File.Open(filename, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        {
            this.workbook = WorkbookFactory.Create(fs);
            this.sheet = workbook.GetSheetAt(0);
        }
        int i = sheet.FirstRowNum;
        // 注释行
        while (i <= sheet.LastRowNum)
        {
            IRow row = sheet.GetRow(i++);
            if (IsSkipRow(row))
                continue;
            if (IsFinishRow(row))
                return false;
            ProcessComment(row);
            break;
        }
        // 列名行
        while (i <= sheet.LastRowNum)
        {
            IRow row = sheet.GetRow(i++);
            if (IsSkipRow(row))
                continue;
            if (IsFinishRow(row))
                return false;
            ProcessHead(row);
            break;
        }

        if (this.header.Count < 1)
            return false;
        while (i <= sheet.LastRowNum)
        {
            IRow row = sheet.GetRow(i++);
            if (IsFinishRow(row))
                return true;
            if (IsSkipRow(row))
                continue;
            ProcessRecord(row);
        }
        return true;
    }
    // 单元类型
    // </summary>
    // <param name="cell"></param>
    // <returns></returns>
    private object GetValueType(ICell cell, out CellType type)
    {
        type = CellType.Error;
        if (cell == null)
            return null;
        type = cell.CellType;
        switch (type)
        {
            case CellType.Boolean:
                return cell.BooleanCellValue;
            case CellType.Numeric:
                if (DateUtil.IsCellDateFormatted(cell))
                    return cell.DateCellValue;
                return cell.NumericCellValue;
            case CellType.String:
                string str = cell.StringCellValue;
                if (string.IsNullOrEmpty(str))
                    return null;
                return str.ToString();
            case CellType.Error:
                return cell.ErrorCellValue;
            case CellType.Formula:
                type = cell.CachedFormulaResultType;
                switch (type)
                {
                    case CellType.Boolean:
                        return cell.BooleanCellValue;
                    case CellType.Numeric:
                        if (DateUtil.IsCellDateFormatted(cell))
                            return cell.DateCellValue;
                        return cell.NumericCellValue;
                    case CellType.String:
                        string strval = cell.StringCellValue;
                        if (string.IsNullOrEmpty(strval))
                            return null;
                        return strval.ToString();
                    case CellType.Error:
                        return cell.ErrorCellValue;
                    case CellType.Unknown:
                    case CellType.Blank:
                    default:
                        return null;       // return "=" + cell.CellFormula;
                }
            case CellType.Unknown:
            case CellType.Blank:
            default:
                return null;              // return "=" + cell.CellFormula;
        }
    }
    private void ProcessComment(IRow comment)
    {
        this.comment.Clear();
        for (int i = comment.FirstCellNum; i < comment.LastCellNum; i++)
        {
            ICell cell = comment.GetCell(i);
            CellType type;
            object obj = GetValueType(cell, out type);
            if (obj != null)
            {
                IColor color = cell.CellStyle.FillForegroundColorColor;
                FieldRule rule = FieldRule.RULE_ERROR;
                if (color == null)
                    rule = FieldRule.RULE_COMMON;
                else
                    rule = GetColorRule(color.RGB);

                string name = obj.ToString();
                if (name != "" && rule != FieldRule.RULE_IGNORE && rule != FieldRule.RULE_ERROR)
                {
                    HeadCol col = new HeadCol();
                    col.index = i;
                    col.rule = rule;
                    col.name = name;
                    col.shortName = name;
                    this.comment.Add(col);
                }
            }
        }
    }
    private void ProcessHead(IRow head)
    {
        this.header.Clear();
        for (int i = head.FirstCellNum; i < head.LastCellNum; i++)
        {
            ICell cell = head.GetCell(i);
            CellType type;
            object obj = GetValueType(cell, out type);
            if (obj != null)
            {
                IColor color = cell.CellStyle.FillForegroundColorColor;
                FieldRule rule = FieldRule.RULE_ERROR;
                if (color == null)
                    rule = FieldRule.RULE_COMMON;
                else
                    rule = GetColorRule(color.RGB);

                string name = obj.ToString();
                if (name != "" && rule != FieldRule.RULE_IGNORE && rule != FieldRule.RULE_ERROR)
                {
                    HeadCol col = new HeadCol();
                    col.index = i;
                    col.rule = rule;
                    col.name = name;
                    int pos = name.IndexOf(":");
                    if (pos > 0)
                    {
                        col.shortName = name.Substring(0, pos);
                    }
                    else
                    {
                        col.shortName = name;
                    }
                    
                    this.header.Add(col);
                }
            }
        }
    }
    private void ProcessRecord(IRow row)
    {
        Dictionary<string, RecordCol> record = new Dictionary<string, RecordCol>();
        for (int i = 0; i < this.header.Count; i++)
        {
            int index = this.header[i].index;
            ICell cell = row.GetCell(index);
            CellType type;
            object obj = GetValueType(cell, out type);
            RecordCol col = new RecordCol();
            col.index = index;
            col.val = obj;
            col.type = type;
            record.Add(this.header[i].name, col);
        }
        this.records.Add(record);
    }
    public bool ExportServerLuaFile(string path)
    {
        string filename = path + this.exportname.ToLower() + ".config";
        StringBuilder sb = new StringBuilder();
        sb.AppendLine("return {");
        DateTime startTime = TimeZone.CurrentTimeZone.ToLocalTime(new System.DateTime(1970, 1, 1));
        int loadCnt = 0;
        foreach (Dictionary<string, RecordCol> record in this.records)
        {
            if (this.header.Count < 1)
                break;
            string field = this.header[0].name;
            string name = this.header[0].shortName;
            string key = record[field].val.ToString();
            if (record[field].type != CellType.Numeric)
                key = QuoteStr(key);         
            string colContent = "\t[" + key + "] = {";
            int colCnt = 0;
            for (int i = 0; i < this.header.Count; i++)
            {
                FieldRule rule = this.header[i].rule;
                field = this.header[i].name;
                name = this.header[i].shortName;
                if (rule == FieldRule.RULE_COMMON || rule == FieldRule.RULE_SERVER)
                {
                    colCnt++;
                    object val = record[field].val;
                    string str = "nil";
                    if (val != null)
                        if (val.GetType() == typeof(DateTime))
                            str = ((int)((DateTime)val - startTime).TotalSeconds).ToString();
                        else if (IsTable(val.ToString()))
                        {
                            str = ConvertLuaTable(val.ToString());
                            //Console.WriteLine("table_convert val=" + val + " str=" + str);
                        }
                        else if (record[field].type == CellType.Boolean)
                            str = val.ToString().ToLower();
                        else
                        {
                            str = QuoteStr(val.ToString());
                            //Console.WriteLine("QuoteStr val=" + val + " str=" + str);
                        }
                    colContent = colContent + " " + name + " = " + str + ",";
                }
            }
            colContent = colContent + " },";
            if (colCnt > 0)
            {
                loadCnt++;
                sb.AppendLine(colContent);
            }
        }
        sb.AppendLine("}");
        if (loadCnt > 0)
        {
            var utf8WithoutBom = new System.Text.UTF8Encoding(false);
            File.WriteAllBytes(filename, utf8WithoutBom.GetBytes(sb.ToString()));
            Console.WriteLine("导出服务端lua文件成功！      " + filename);
        }
        else
        {
            Console.WriteLine("服务端lua文件为空，不导出！  " + filename);
        }
        return true;
    }
    public bool ExportClientLuaFile(string path)
    {
        string filename = path + this.exportname.ToLower() + ".lua";
        StringBuilder sb = new StringBuilder();
        sb.AppendLine("return {");
        int loadCnt = 0;
        DateTime startTime = TimeZone.CurrentTimeZone.ToLocalTime(new System.DateTime(1970, 1, 1));
        foreach (Dictionary<string, RecordCol> record in this.records)
        {
            if (this.header.Count < 1)
                break;
            string field = this.header[0].name;
            string name = this.header[0].shortName;
            string key = record[field].val.ToString();
            if (record[field].type != CellType.Numeric)
                key = QuoteStr(key);
            int colCnt = 0;
            string colContent = "\t[" + key + "] = {";
            for (int i = 0; i < this.header.Count; i++)
            {
                FieldRule rule = this.header[i].rule;
                field = this.header[i].name;
                name = this.header[i].shortName;
                if (rule == FieldRule.RULE_COMMON || rule == FieldRule.RULE_CLIENT)
                {
                    colCnt++;
                    object val = record[field].val;
                    string str = "nil";
                    if (val != null)
                    {
                        if (val.GetType() == typeof(DateTime))
                            str = ((int)((DateTime)val - startTime).TotalSeconds).ToString();
                        else if (IsTable(val.ToString()))
                            str = ConvertLuaTable(val.ToString());
                        else if (record[field].type == CellType.Boolean)
                            str = val.ToString().ToLower();
                        else
                            str = QuoteStr(val.ToString());
                    }
                    colContent = colContent + " " + name + " = " + str + ",";
                }
            }
            colContent = colContent + " },";
            if (colCnt > 0)
            {
                loadCnt++;
                sb.AppendLine(colContent);
            }
        }
        sb.AppendLine("}");
        if (loadCnt > 0)
        {
            var utf8WithoutBom = new System.Text.UTF8Encoding(false);
            File.WriteAllBytes(filename, utf8WithoutBom.GetBytes(sb.ToString()));
            Console.WriteLine("导出客户端lua文件成功！      " + filename);
        }
        else
        {
            Console.WriteLine("客户端lua文件为空，不导出！  " + filename);
        }
        return true;
    }
    public bool ExportCsvFile(string path)
    {
        string filename = path + this.exportname + ".csv";
        var utf8WithoutBom = new System.Text.UTF8Encoding(false);
        int colCnt = 0;
        using (StreamWriter writer = new StreamWriter(filename, false, utf8WithoutBom))
        {
            bool isFirstCol = true;
            for (int i = 0; i < this.comment.Count; i++)
            {
                FieldRule rule = FieldRule.RULE_ERROR;
                for (int j = 0; j < this.header.Count; j++)
                {
                    if (this.header[j].index == i)
                    {
                        rule = this.header[j].rule;
                        break;
                    }
                }
                if (rule == FieldRule.RULE_CLIENT || rule == FieldRule.RULE_COMMON)
                {
                    if (!isFirstCol)
                        writer.Write(",");
                    isFirstCol = false;
                    writer.Write(this.comment[i].name);
                    colCnt++;
                }
            }
            writer.WriteLine();

            isFirstCol = true;
            for (int i = 0; i < this.header.Count; i++)
            {
                FieldRule rule = this.header[i].rule;
                if (rule == FieldRule.RULE_CLIENT || rule == FieldRule.RULE_COMMON)
                {
                    if (!isFirstCol)
                        writer.Write(",");
                    isFirstCol = false;
                    writer.Write(this.header[i].name);
                    colCnt++;
                }
            }
            writer.WriteLine();

            DateTime startTime = TimeZone.CurrentTimeZone.ToLocalTime(new System.DateTime(1970, 1, 1));
            foreach (Dictionary<string, RecordCol> record in this.records)
            {
                isFirstCol = true;
                int cnt = 0;
                for (int i = 0; i < this.header.Count; i++)
                {
                    FieldRule rule = this.header[i].rule;
                    string field = this.header[i].name;
                    if (rule == FieldRule.RULE_COMMON || rule == FieldRule.RULE_CLIENT)
                    {
                        cnt++;
                        object val = record[field].val;
                        string str = "";
                        if (val != null)
                        {
                            if (val.GetType() == typeof(DateTime))
                                str = ((int)((DateTime)val - startTime).TotalSeconds).ToString();
                            else
                                str = QuoteCsvString(val.ToString());
                        }
                        if (!isFirstCol)
                            writer.Write(",");
                        isFirstCol = false;
                        writer.Write(str);
                    }
                }
                if (cnt > 0)
                {
                    colCnt = colCnt + cnt;
                    writer.WriteLine();
                }
            }
            if (colCnt > 0)
            {
                string cntStr = colCnt.ToString();
                Console.WriteLine("导出csv文件成功！            " + filename);
                return true;
            }
            else
            {
                writer.Close();
                File.Delete(filename);
                Console.WriteLine("csv文件为空，不导出！        " + filename);
                return true;
            }
        }
        //return false;
    }

    static void Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Usage: {0} excel_file server_out client_out csv_out", Process.GetCurrentProcess().ProcessName);
            Console.ReadLine();
            return;
        }
        
        //string[] args2 = { "E:\\cs\\cs\\cs\\bin\\Debug\\", "E:\\cs\\cs\\cs\\bin\\Debug\\", "E:\\cs\\cs\\cs\\bin\\Debug\\web.xlsx" };
        string file = args[0];
        CfgExportor export = new CfgExportor(file);
        if (!export.LoadFile())
            Console.WriteLine("加载文件：" + file + " 失败！");
        else
        {
            //if (!export.ExportCsvFile(args[0]))
            //    Console.WriteLine("导出 csv 文件失败！");
            //else
            //    Console.WriteLine("导出 csv 文件成功！");
            if (!export.ExportServerLuaFile(args[1]))
                Console.WriteLine("导出服务端 lua 文件失败！  " + file);

            if (args.Length >= 3)
            {
                if (!export.ExportClientLuaFile(args[2]))
                    Console.WriteLine("导出客户端 lua 文件失败！  " + file);
            }
            
            if (args.Length >= 4)
            {
                if (!export.ExportCsvFile(args[3]))
                {
                    Console.WriteLine("导出 csv 文件失败！");
                }
            }
            Console.WriteLine("导出完成！");
        }
        //Console.ReadKey();
    }
}