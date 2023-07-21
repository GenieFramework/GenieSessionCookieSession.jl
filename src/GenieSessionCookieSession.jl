module GenieSessionCookieSession

import Genie, GenieSession
import Serialization, Logging
using Genie.Context, Genie.Cookies
using Base64


const COOKIE_KEY_NAME = Ref{String}("__geniesessdata")

function cookie_key_name()
  COOKIE_KEY_NAME[]
end

function cookie_key_name(name::String)
  COOKIE_KEY_NAME[] = name
end


"""
    write(params::Params) :: GenieSession.Session

Persists the `Session` object to the cookie and returns it.
"""
function GenieSession.write(params::Params) :: GenieSession.Session
  try
    write_session(params, params[:session])

    return params[:session]
  catch ex
    @error "Failed to store session data"
    @error ex
  end

  try
    @error "Resetting session"

    session = GenieSession.Session(GenieSession.id())
    Genie.Cookies.set!(params[:response], GenieSession.session_key_name(), session.id, GenieSession.session_options())
    write_session(params, session)

    return session
  catch ex
    @error "Failed to regenerate and store session data. Giving up."
    @error ex
  end

  params[:session]
end


function write_session(params::Genie.Context.Params, session::GenieSession.Session)
  io = IOBuffer()
  iob64_encode = Base64EncodePipe(io)
  Serialization.serialize(iob64_encode, session)
  close(iob64_encode)

  Genie.Cookies.set!(params, cookie_key_name(), String(take!(io)), GenieSession.session_options())
end


"""
    read(req::HTTP.Request) :: Union{Nothing,GenieSession.Session}

Attempts to read from file the session object serialized as `session_id`.
"""
function read(req) :: Union{Nothing,GenieSession.Session}
  try
    io = IOBuffer()
    iob64_decode = Base64DecodePipe(io)
    content = Genie.Cookies.get(req, cookie_key_name())
    content === nothing && return nothing

    Base.write(io, content)
    seekstart(io)
    Serialization.deserialize(iob64_decode)
  catch ex
    @error "Can't read session"
    @error ex

    nothing
  end
end


#===#
# IMPLEMENTATION


"""
    load(req::HTTP.Request, res::HTTP.Response, session_id::String) :: Session

Loads session data from persistent storage.
"""
function GenieSession.load(req, res, session_id::String) :: GenieSession.Session
  session = read(req)

  session === nothing ? GenieSession.Session(session_id) : (session)
end

end
