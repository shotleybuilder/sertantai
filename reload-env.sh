#!/bin/bash
# Script to reload environment variables after ~/.bashrc changes

echo "Reloading environment variables from ~/.bashrc..."
source ~/.bashrc

echo ""
echo "Verifying Supabase environment variables:"
echo "========================================="
echo "SUPABASE_PROJECT_ID: ${SUPABASE_PROJECT_ID}"
echo "SUPABASE_HOST: ${SUPABASE_HOST}"
echo "SUPABASE_POOLER_HOST: ${SUPABASE_POOLER_HOST}"
echo "SUPABASE_DB_PASSWORD: ${SUPABASE_DB_PASSWORD}"
echo "SUPABASE_DATABASE: ${SUPABASE_DATABASE}"
echo "DATABASE_URL: ${DATABASE_URL}"
echo "SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo "SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY:0:20}..."
echo ""
echo "Legacy variables (for backwards compatibility):"
echo "SUPABASE_PASSWORD: ${SUPABASE_PASSWORD}"
echo "SUPABASE_KEY: ${SUPABASE_KEY:0:20}..."
echo ""
echo "Environment variables have been reloaded successfully!"
echo ""
echo "To make these changes permanent in your current shell, run:"
echo "source ~/.bashrc"