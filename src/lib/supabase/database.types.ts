
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "public": {
          Tables: {
            "audit_events": {
                  Row: {
                    "actor_id": string | null,"actor_role": string,"changed": NonNullable<Json>,"command": string | null,"entity_id": string,"id": number,"idempotency_key": string | null,"occurred_at": string,"organization_id": string,"table_name": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"actor_role": string,"changed": NonNullable<Json>,"command"?: string | null,"entity_id": string,"id"?: never,"idempotency_key"?: string | null,"occurred_at"?: string,"organization_id": string,"table_name": string
                  }
                  Update: {
                    "actor_id"?: string | null,"actor_role"?: string,"changed"?: NonNullable<Json>,"command"?: string | null,"entity_id"?: string,"id"?: never,"idempotency_key"?: string | null,"occurred_at"?: string,"organization_id"?: string,"table_name"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "audit_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"care_notes": {
                  Row: {
                    "author_name": string | null,"case_id": string | null,"content": string,"created_at": string,"id": string,"note_type": string,"organization_id": string,"status": string,"team_id": string | null,"visit_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "author_name"?: string | null,"case_id"?: string | null,"content": string,"created_at"?: string,"id"?: string,"note_type": string,"organization_id": string,"status"?: string,"team_id"?: string | null,"visit_id"?: string | null
                  }
                  Update: {
                    "author_name"?: string | null,"case_id"?: string | null,"content"?: string,"created_at"?: string,"id"?: string,"note_type"?: string,"organization_id"?: string,"status"?: string,"team_id"?: string | null,"visit_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "care_notes_case_id_fkey"
      columns: ["case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_notes_case_same_org"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "care_notes_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_notes_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_notes_team_same_org"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "care_notes_visit_id_fkey"
      columns: ["visit_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_notes_visit_same_org"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"care_visits": {
                  Row: {
                    "billable": boolean | null,"case_id": string | null,"created_at": string,"id": string,"notes": string | null,"organization_id": string,"services_provided": (string)[] | null,"status": string | null,"team_id": string | null,"team_member_name": string | null,"time_end": string | null,"time_start": string | null,"visit_date": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "billable"?: boolean | null,"case_id"?: string | null,"created_at"?: string,"id"?: string,"notes"?: string | null,"organization_id": string,"services_provided"?: (string)[] | null,"status"?: string | null,"team_id"?: string | null,"team_member_name"?: string | null,"time_end"?: string | null,"time_start"?: string | null,"visit_date"?: string | null
                  }
                  Update: {
                    "billable"?: boolean | null,"case_id"?: string | null,"created_at"?: string,"id"?: string,"notes"?: string | null,"organization_id"?: string,"services_provided"?: (string)[] | null,"status"?: string | null,"team_id"?: string | null,"team_member_name"?: string | null,"time_end"?: string | null,"time_start"?: string | null,"visit_date"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "care_visits_case_id_fkey"
      columns: ["case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_visits_case_same_org"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "care_visits_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_visits_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_visits_team_same_org"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"cases": {
                  Row: {
                    "address": string | null,"assigned_team": string | null,"assigned_team_id": string | null,"bedarf": string | null,"care_level": string | null,"care_needs": (string)[] | null,"cognitive_status": string | null,"created_at": string,"date_of_birth": string | null,"diagnosis_tags": (string)[] | null,"emergency_contact_name": string | null,"emergency_contact_phone": string | null,"first_name": string | null,"gender": string | null,"id": string,"insurance_provider": string | null,"last_name": string | null,"mobility_status": string | null,"name": string | null,"next_step": string | null,"notes": string | null,"organization_id": string,"ort": string | null,"phone": string | null,"plz": string | null,"referral_source": string | null,"region": string | null,"start_date": string | null,"status": string | null,"time_info": string | null,"urgency": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "address"?: string | null,"assigned_team"?: string | null,"assigned_team_id"?: string | null,"bedarf"?: string | null,"care_level"?: string | null,"care_needs"?: (string)[] | null,"cognitive_status"?: string | null,"created_at"?: string,"date_of_birth"?: string | null,"diagnosis_tags"?: (string)[] | null,"emergency_contact_name"?: string | null,"emergency_contact_phone"?: string | null,"first_name"?: string | null,"gender"?: string | null,"id"?: string,"insurance_provider"?: string | null,"last_name"?: string | null,"mobility_status"?: string | null,"name"?: string | null,"next_step"?: string | null,"notes"?: string | null,"organization_id": string,"ort"?: string | null,"phone"?: string | null,"plz"?: string | null,"referral_source"?: string | null,"region"?: string | null,"start_date"?: string | null,"status"?: string | null,"time_info"?: string | null,"urgency"?: string | null
                  }
                  Update: {
                    "address"?: string | null,"assigned_team"?: string | null,"assigned_team_id"?: string | null,"bedarf"?: string | null,"care_level"?: string | null,"care_needs"?: (string)[] | null,"cognitive_status"?: string | null,"created_at"?: string,"date_of_birth"?: string | null,"diagnosis_tags"?: (string)[] | null,"emergency_contact_name"?: string | null,"emergency_contact_phone"?: string | null,"first_name"?: string | null,"gender"?: string | null,"id"?: string,"insurance_provider"?: string | null,"last_name"?: string | null,"mobility_status"?: string | null,"name"?: string | null,"next_step"?: string | null,"notes"?: string | null,"organization_id"?: string,"ort"?: string | null,"phone"?: string | null,"plz"?: string | null,"referral_source"?: string | null,"region"?: string | null,"start_date"?: string | null,"status"?: string | null,"time_info"?: string | null,"urgency"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "cases_assigned_team_id_fkey"
      columns: ["assigned_team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cases_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cases_team_same_org"
      columns: ["assigned_team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"match_candidates": {
                  Row: {
                    "created_at": string,"distance_km": number | null,"fit_score": number,"id": string,"matching_request_id": string | null,"open_slots": number | null,"organization_id": string,"reasons": (string)[] | null,"status": string,"team_id": string | null,"utilization": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"distance_km"?: number | null,"fit_score"?: number,"id"?: string,"matching_request_id"?: string | null,"open_slots"?: number | null,"organization_id": string,"reasons"?: (string)[] | null,"status"?: string,"team_id"?: string | null,"utilization"?: number | null
                  }
                  Update: {
                    "created_at"?: string,"distance_km"?: number | null,"fit_score"?: number,"id"?: string,"matching_request_id"?: string | null,"open_slots"?: number | null,"organization_id"?: string,"reasons"?: (string)[] | null,"status"?: string,"team_id"?: string | null,"utilization"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "match_candidates_matching_request_id_fkey"
      columns: ["matching_request_id"]
isOneToOne: false
      referencedRelation: "matching_requests"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "match_candidates_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "match_candidates_request_same_org"
      columns: ["matching_request_id","organization_id"]
isOneToOne: false
      referencedRelation: "matching_requests"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "match_candidates_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "match_candidates_team_same_org"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"matching_requests": {
                  Row: {
                    "case_id": string | null,"created_at": string,"id": string,"notes": string | null,"organization_id": string,"region": string,"request_title": string,"required_services": (string)[] | null,"selected_team_id": string | null,"status": string,"urgency": string
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id"?: string | null,"created_at"?: string,"id"?: string,"notes"?: string | null,"organization_id": string,"region": string,"request_title": string,"required_services"?: (string)[] | null,"selected_team_id"?: string | null,"status"?: string,"urgency": string
                  }
                  Update: {
                    "case_id"?: string | null,"created_at"?: string,"id"?: string,"notes"?: string | null,"organization_id"?: string,"region"?: string,"request_title"?: string,"required_services"?: (string)[] | null,"selected_team_id"?: string | null,"status"?: string,"urgency"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "matching_requests_case_id_fkey"
      columns: ["case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "matching_requests_case_same_org"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "matching_requests_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "matching_requests_selected_team_id_fkey"
      columns: ["selected_team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "matching_requests_team_same_org"
      columns: ["selected_team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"organization_memberships": {
                  Row: {
                    "created_at": string,"organization_id": string,"role": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"organization_id": string,"role": string,"user_id": string
                  }
                  Update: {
                    "created_at"?: string,"organization_id"?: string,"role"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "organization_memberships_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"organizations": {
                  Row: {
                    "created_at": string,"id": string,"name": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"name": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"name"?: string
                  }
                  Relationships: [
                    
                  ]
                },"partner_requests": {
                  Row: {
                    "city": string | null,"converted_case_id": string | null,"created_at": string,"id": string,"need_summary": string,"notes": string | null,"organization_id": string,"partner_name": string,"partner_type": string | null,"region": string,"request_title": string,"requested_services": (string)[] | null,"status": string,"time_info": string | null,"urgency": string
                  }
                  ComputedFields: never
                  Insert: {
                    "city"?: string | null,"converted_case_id"?: string | null,"created_at"?: string,"id"?: string,"need_summary": string,"notes"?: string | null,"organization_id": string,"partner_name": string,"partner_type"?: string | null,"region": string,"request_title": string,"requested_services"?: (string)[] | null,"status"?: string,"time_info"?: string | null,"urgency": string
                  }
                  Update: {
                    "city"?: string | null,"converted_case_id"?: string | null,"created_at"?: string,"id"?: string,"need_summary"?: string,"notes"?: string | null,"organization_id"?: string,"partner_name"?: string,"partner_type"?: string | null,"region"?: string,"request_title"?: string,"requested_services"?: (string)[] | null,"status"?: string,"time_info"?: string | null,"urgency"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "partner_requests_case_same_org"
      columns: ["converted_case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "partner_requests_converted_case_id_fkey"
      columns: ["converted_case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "partner_requests_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"quality_events": {
                  Row: {
                    "case_id": string | null,"created_at": string,"description": string | null,"event_type": string,"id": string,"organization_id": string,"severity": string,"status": string,"team_id": string | null,"title": string,"visit_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id"?: string | null,"created_at"?: string,"description"?: string | null,"event_type": string,"id"?: string,"organization_id": string,"severity": string,"status"?: string,"team_id"?: string | null,"title": string,"visit_id"?: string | null
                  }
                  Update: {
                    "case_id"?: string | null,"created_at"?: string,"description"?: string | null,"event_type"?: string,"id"?: string,"organization_id"?: string,"severity"?: string,"status"?: string,"team_id"?: string | null,"title"?: string,"visit_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "quality_events_case_id_fkey"
      columns: ["case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_events_case_same_org"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "quality_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_events_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_events_team_same_org"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "quality_events_visit_id_fkey"
      columns: ["visit_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_events_visit_same_org"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"team_memberships": {
                  Row: {
                    "created_at": string,"team_id": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"team_id": string,"user_id": string
                  }
                  Update: {
                    "created_at"?: string,"team_id"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "team_memberships_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    }
                  ]
                },"teams": {
                  Row: {
                    "care_focus": string | null,"coach_name": string | null,"created_at": string,"id": string,"lead_name": string | null,"name": string,"next_step": string | null,"open_slots": number | null,"organization_id": string,"priority": boolean | null,"region": string | null,"status": string | null,"utilization": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "care_focus"?: string | null,"coach_name"?: string | null,"created_at"?: string,"id"?: string,"lead_name"?: string | null,"name": string,"next_step"?: string | null,"open_slots"?: number | null,"organization_id": string,"priority"?: boolean | null,"region"?: string | null,"status"?: string | null,"utilization"?: number | null
                  }
                  Update: {
                    "care_focus"?: string | null,"coach_name"?: string | null,"created_at"?: string,"id"?: string,"lead_name"?: string | null,"name"?: string,"next_step"?: string | null,"open_slots"?: number | null,"organization_id"?: string,"priority"?: boolean | null,"region"?: string | null,"status"?: string | null,"utilization"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "teams_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"visit_events": {
                  Row: {
                    "actor_id": string | null,"command": string | null,"event_type": string,"from_status": string,"id": number,"idempotency_key": string | null,"occurred_at": string,"organization_id": string,"team_id": string | null,"to_status": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"command"?: string | null,"event_type": string,"from_status": string,"id"?: never,"idempotency_key"?: string | null,"occurred_at"?: string,"organization_id": string,"team_id"?: string | null,"to_status": string,"visit_id": string
                  }
                  Update: {
                    "actor_id"?: string | null,"command"?: string | null,"event_type"?: string,"from_status"?: string,"id"?: never,"idempotency_key"?: string | null,"occurred_at"?: string,"organization_id"?: string,"team_id"?: string | null,"to_status"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_events_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"visit_time_corrections": {
                  Row: {
                    "actor_id": string,"corrected_at": string,"created_at": string,"event_id": number,"id": number,"idempotency_key": string,"organization_id": string,"reason": string,"team_id": string | null,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"corrected_at": string,"created_at"?: string,"event_id": number,"id"?: never,"idempotency_key": string,"organization_id": string,"reason": string,"team_id"?: string | null,"visit_id": string
                  }
                  Update: {
                    "actor_id"?: string,"corrected_at"?: string,"created_at"?: string,"event_id"?: number,"id"?: never,"idempotency_key"?: string,"organization_id"?: string,"reason"?: string,"team_id"?: string | null,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_time_corrections_event_id_fkey"
      columns: ["event_id"]
isOneToOne: false
      referencedRelation: "visit_events"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_time_corrections_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_time_corrections_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "assign_team_coach":
{ Args: { "p_coach_name": string,"p_idempotency_key": string,"p_team_id": string }; Returns: string
                           },
"complete_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"correct_visit_time":
{ Args: { "p_corrected_at": string,"p_event_id": number,"p_idempotency_key": string,"p_reason": string }; Returns: string
                           },
"depart_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"field_visits":
{ Args: { "p_date": string }; Returns: {
              "address": string,"care_needs": (string)[],"case_id": string,"client_name": string,"events": Json,"ort": string,"plz": string,"services_provided": (string)[],"status": string,"team_id": string,"team_name": string,"time_end": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"pause_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"resume_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"set_team_priority":
{ Args: { "p_idempotency_key": string,"p_priority": boolean,"p_team_id": string }; Returns: string
                           },
"start_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "public": {
          Enums: {
            
          }
        }
} as const
