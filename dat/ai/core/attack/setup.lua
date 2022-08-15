local atk = {}

local usable_outfits = {
   ["Emergency Shield Booster"] = "shield_booster",
}

function atk.setup( p )
   local added = false

   -- Clean up old stuff
   local m = p:memory()
   m._o = nil
   local o = {}

   -- Check out what interesting outfits there are
   for k,v in ipairs(p:outfits()) do
      if v then
         local var = usable_outfits[ v:nameRaw() ]
         if var then
            o[var] = k
            added = true
         end
      end
   end

   -- Actually added an outfit, so we set the list
   if added then
      m._o = o
   end
end

return atk
