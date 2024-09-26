export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never;
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      graphql: {
        Args: {
          operationName?: string;
          query?: string;
          variables?: Json;
          extensions?: Json;
        };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  public: {
    Tables: {
      beradrome_rewarders: {
        Row: {
          address: string;
          id: number;
          vault: string;
        };
        Insert: {
          address: string;
          id?: number;
          vault: string;
        };
        Update: {
          address?: string;
          id?: number;
          vault?: string;
        };
        Relationships: [];
      };
      contracts: {
        Row: {
          address: string;
          id: number;
          is_allowed: boolean;
          name: string | null;
          protocol: string;
          token_address: string | null;
        };
        Insert: {
          address: string;
          id?: number;
          is_allowed: boolean;
          name?: string | null;
          protocol: string;
          token_address?: string | null;
        };
        Update: {
          address?: string;
          id?: number;
          is_allowed?: boolean;
          name?: string | null;
          protocol?: string;
          token_address?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "contracts_protocol_fkey";
            columns: ["protocol"];
            isOneToOne: false;
            referencedRelation: "protocols";
            referencedColumns: ["name"];
          },
          {
            foreignKeyName: "contracts_token_address_fkey";
            columns: ["token_address"];
            isOneToOne: false;
            referencedRelation: "lp_tokens";
            referencedColumns: ["address"];
          }
        ];
      };
      function_selectors: {
        Row: {
          action: string;
          created_at: string | null;
          function_signature: string;
          id: number;
          is_allowed: boolean;
          protocol: string;
          selector: string;
        };
        Insert: {
          action: string;
          created_at?: string | null;
          function_signature: string;
          id?: number;
          is_allowed: boolean;
          protocol: string;
          selector: string;
        };
        Update: {
          action?: string;
          created_at?: string | null;
          function_signature?: string;
          id?: number;
          is_allowed?: boolean;
          protocol?: string;
          selector?: string;
        };
        Relationships: [
          {
            foreignKeyName: "function_selectors_protocol_fkey";
            columns: ["protocol"];
            isOneToOne: false;
            referencedRelation: "protocols";
            referencedColumns: ["name"];
          }
        ];
      };
      lp_tokens: {
        Row: {
          address: string;
          authorized: boolean;
          icon_url: string | null;
          id: number;
          name: string;
          protocol: string;
        };
        Insert: {
          address: string;
          authorized: boolean;
          icon_url?: string | null;
          id?: number;
          name: string;
          protocol: string;
        };
        Update: {
          address?: string;
          authorized?: boolean;
          icon_url?: string | null;
          id?: number;
          name?: string;
          protocol?: string;
        };
        Relationships: [];
      };
      non_lp_tokens: {
        Row: {
          address: string;
          authorized: boolean;
          icon_url: string | null;
          id: number;
          is_locked: boolean | null;
          name: string;
        };
        Insert: {
          address: string;
          authorized: boolean;
          icon_url?: string | null;
          id?: number;
          is_locked?: boolean | null;
          name: string;
        };
        Update: {
          address?: string;
          authorized?: boolean;
          icon_url?: string | null;
          id?: number;
          is_locked?: boolean | null;
          name?: string;
        };
        Relationships: [];
      };
      protocols: {
        Row: {
          icon_url: string | null;
          id: number;
          name: string;
        };
        Insert: {
          icon_url?: string | null;
          id?: number;
          name: string;
        };
        Update: {
          icon_url?: string | null;
          id?: number;
          name?: string;
        };
        Relationships: [];
      };
      referrers: {
        Row: {
          address: string;
          id: number;
          name: string;
        };
        Insert: {
          address: string;
          id?: number;
          name: string;
        };
        Update: {
          address?: string;
          id?: number;
          name?: string;
        };
        Relationships: [];
      };
      sf_users: {
        Row: {
          address: string;
          created_at: string;
          id: number;
          locker_address: string;
          pool_id: number | null;
          pool_type: string | null;
          project_id: string | null;
          type: string;
        };
        Insert: {
          address: string;
          created_at?: string;
          id?: number;
          locker_address: string;
          pool_id?: number | null;
          pool_type?: string | null;
          project_id?: string | null;
          type: string;
        };
        Update: {
          address?: string;
          created_at?: string;
          id?: number;
          locker_address?: string;
          pool_id?: number | null;
          pool_type?: string | null;
          project_id?: string | null;
          type?: string;
        };
        Relationships: [];
      };
      vaults: {
        Row: {
          address: string | null;
          created_at: string;
          id: number;
          name: string | null;
        };
        Insert: {
          address?: string | null;
          created_at?: string;
          id?: number;
          name?: string | null;
        };
        Update: {
          address?: string | null;
          created_at?: string;
          id?: number;
          name?: string | null;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      [_ in never]: never;
    };
    Enums: {
      protocol: "BEX" | "KODIAK";
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type PublicSchema = Database[Extract<keyof Database, "public">];

export type Tables<
  PublicTableNameOrOptions extends
    | keyof (PublicSchema["Tables"] & PublicSchema["Views"])
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
        Database[PublicTableNameOrOptions["schema"]]["Views"])
    : never = never
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? (Database[PublicTableNameOrOptions["schema"]]["Tables"] &
      Database[PublicTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : PublicTableNameOrOptions extends keyof (PublicSchema["Tables"] &
      PublicSchema["Views"])
  ? (PublicSchema["Tables"] &
      PublicSchema["Views"])[PublicTableNameOrOptions] extends {
      Row: infer R;
    }
    ? R
    : never
  : never;

export type TablesInsert<
  PublicTableNameOrOptions extends
    | keyof PublicSchema["Tables"]
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : PublicTableNameOrOptions extends keyof PublicSchema["Tables"]
  ? PublicSchema["Tables"][PublicTableNameOrOptions] extends {
      Insert: infer I;
    }
    ? I
    : never
  : never;

export type TablesUpdate<
  PublicTableNameOrOptions extends
    | keyof PublicSchema["Tables"]
    | { schema: keyof Database },
  TableName extends PublicTableNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = PublicTableNameOrOptions extends { schema: keyof Database }
  ? Database[PublicTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : PublicTableNameOrOptions extends keyof PublicSchema["Tables"]
  ? PublicSchema["Tables"][PublicTableNameOrOptions] extends {
      Update: infer U;
    }
    ? U
    : never
  : never;

export type Enums<
  PublicEnumNameOrOptions extends
    | keyof PublicSchema["Enums"]
    | { schema: keyof Database },
  EnumName extends PublicEnumNameOrOptions extends { schema: keyof Database }
    ? keyof Database[PublicEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = PublicEnumNameOrOptions extends { schema: keyof Database }
  ? Database[PublicEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : PublicEnumNameOrOptions extends keyof PublicSchema["Enums"]
  ? PublicSchema["Enums"][PublicEnumNameOrOptions]
  : never;
