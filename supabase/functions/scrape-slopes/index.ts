// Supabase Edge Function to scrape KitzSki slope status
// Deploy with: supabase functions deploy scrape-slopes
// Schedule with: Supabase Dashboard > Database > pg_cron

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const KITZSKI_URL = 'https://www.kitzski.at/de/aktuelle-info/pistenstatus.html'

interface SlopeStatus {
  name: string
  status: 'open' | 'closed' | 'unknown'
  difficulty?: string
  length?: string
  vertical?: string
}

interface LiftStatus {
  name: string
  status: 'open' | 'closed' | 'unknown'
  type?: string
}

interface ScrapedData {
  slopes: SlopeStatus[]
  lifts: LiftStatus[]
  lastUpdated: string
  source: string
}

Deno.serve(async (req) => {
  try {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    }

    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

    console.log('Fetching KitzSki page...')

    // Fetch the KitzSki page
    const response = await fetch(KITZSKI_URL, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
      },
    })

    if (!response.ok) {
      throw new Error(`Failed to fetch: ${response.status}`)
    }

    const html = await response.text()
    console.log('HTML length:', html.length)
    
    const slopes: SlopeStatus[] = []
    const lifts: LiftStatus[] = []
    
    // Pattern to match table rows with slope data
    // Looking for: Geöffnet/Geschlossen, Leicht/Mittel/Schwer, slope name, length, vertical
    
    // Match rows that contain status (Geöffnet or Geschlossen)
    const rowPattern = /<tr[^>]*>[\s\S]*?<\/tr>/gi
    const rows = html.match(rowPattern) || []
    
    console.log('Found rows:', rows.length)
    
    for (const row of rows) {
      // Check if this row has status info
      const hasStatus = /geöffnet|geschlossen/i.test(row)
      if (!hasStatus) continue
      
      // Extract status
      const isOpen = /geöffnet/i.test(row)
      
      // Extract difficulty (Leicht = easy/blue, Mittel = medium/red, Schwer = hard/black)
      let difficulty = 'unknown'
      if (/leicht/i.test(row)) difficulty = 'easy'
      else if (/mittel/i.test(row)) difficulty = 'intermediate'
      else if (/schwer/i.test(row)) difficulty = 'advanced'
      
      // Extract name from cells - usually the third td or one with the piste name
      // Clean HTML tags and get text content
      const cells = row.match(/<td[^>]*>([\s\S]*?)<\/td>/gi) || []
      
      let name = ''
      let length = ''
      let vertical = ''
      
      // Parse each cell
      cells.forEach((cell, index) => {
        const text = cell.replace(/<[^>]+>/g, '').trim()
        
        // Skip empty cells or status/difficulty cells
        if (!text || /geöffnet|geschlossen|leicht|mittel|schwer/i.test(text)) {
          return
        }
        
        // Check if it's a measurement (ends with 'm')
        if (/^\d+\s*m$/.test(text)) {
          if (!length) length = text
          else vertical = text
        } else if (text.length > 2 && !name) {
          // This is likely the slope name
          name = text
        }
      })
      
      if (name) {
        slopes.push({
          name,
          status: isOpen ? 'open' : 'closed',
          difficulty,
          length: length || undefined,
          vertical: vertical || undefined
        })
      }
    }
    
    // Also try to find lift data (Bergbahnen/Lifte section)
    const liftPattern = /([\w\s-]+(?:bahn|lift|gondel|sessellift|schlepplift)[\w\s-]*)/gi
    const liftMatches = html.match(liftPattern) || []
    
    // Look for lifts in a similar table structure
    for (const row of rows) {
      const hasLiftKeyword = /bahn|lift|gondel|sessel|schlepp/i.test(row)
      if (!hasLiftKeyword) continue
      
      const isOpen = /geöffnet/i.test(row)
      const isClosed = /geschlossen/i.test(row)
      
      if (!isOpen && !isClosed) continue
      
      const cells = row.match(/<td[^>]*>([\s\S]*?)<\/td>/gi) || []
      
      for (const cell of cells) {
        const text = cell.replace(/<[^>]+>/g, '').trim()
        if (/bahn|lift|gondel|sessel|schlepp/i.test(text) && text.length > 3 && text.length < 60) {
          // Determine lift type
          let liftType = 'lift'
          if (/gondel/i.test(text)) liftType = 'gondola'
          else if (/sessel/i.test(text)) liftType = 'chairlift'
          else if (/schlepp/i.test(text)) liftType = 'dragLift'
          
          lifts.push({
            name: text,
            status: isOpen ? 'open' : 'closed',
            type: liftType
          })
          break
        }
      }
    }

    console.log('Parsed slopes:', slopes.length)
    console.log('Parsed lifts:', lifts.length)
    
    // Debug: log first few slopes
    if (slopes.length > 0) {
      console.log('Sample slopes:', JSON.stringify(slopes.slice(0, 3)))
    }

    const data: ScrapedData = {
      slopes,
      lifts,
      lastUpdated: new Date().toISOString(),
      source: 'kitzski.at'
    }

    // Save to Supabase database
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey)
      
      // Count open/closed
      const slopesOpen = slopes.filter(s => s.status === 'open').length
      const liftsOpen = lifts.filter(l => l.status === 'open').length
      
      console.log('Saving to database:', { slopesOpen, slopesTotal: slopes.length, liftsOpen, liftsTotal: lifts.length })
      
      // Insert new status record
      const { error } = await supabase
        .from('slope_status')
        .insert({
          resort: 'kitzbuehel',
          slopes_open: slopesOpen,
          slopes_total: slopes.length,
          lifts_open: liftsOpen,
          lifts_total: lifts.length,
          slopes: slopes,
          lifts: lifts,
          source_url: KITZSKI_URL,
          updated_at: new Date().toISOString()
        })
      
      if (error) {
        console.error('Database error:', error)
      } else {
        console.log('Successfully saved to database')
      }
    }

    return new Response(
      JSON.stringify(data, null, 2),
      { 
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        } 
      }
    )

  } catch (error) {
    console.error('Scraping error:', error)
    
    return new Response(
      JSON.stringify({ 
        error: error.message,
        slopes: [],
        lifts: [],
        lastUpdated: new Date().toISOString()
      }),
      { 
        status: 500,
        headers: { 
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'application/json' 
        } 
      }
    )
  }
})
