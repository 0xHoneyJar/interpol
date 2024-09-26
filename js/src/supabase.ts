import { createClient } from "@supabase/supabase-js";
import { Database } from "../types/supabase";

import dotenv from "dotenv";
dotenv.config();

const supabaseUrl = "https://eyjyjfmyutubayyikafs.supabase.co";
const supabaseKey = process.env.SUPABASE_KEY!;
const supabase = createClient<Database>(supabaseUrl, supabaseKey);

export default supabase;
